// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice External agent-identity registry (e.g. an Agent ID registry adapter).
/// @dev    The registry itself is NOT part of this repository. Before launch, the
///         owner points `agentGate` at the real registry adapter contract whose
///         `isAgent` answers "does this address hold a valid Agent ID?".
interface IAgentGate {
    function isAgent(address account) external view returns (bool);
}

/// @title  Eonvera — Time, Minted by Machines
/// @notice ERC-721 for the Eonvera collection on BNB Chain (chain ID 56).
///
///         Concept, mirroring https://eonvera.vercel.app :
///         - ONE single series, fixed forever at 3,333 works (token IDs 1..3333).
///         - Agent-only minting: `mint()` is callable only by an address that
///           holds an Agent ID, proven through the agent gate (external registry
///           adapter and/or the owner-managed agent allowlist). There is no
///           public mint path at all.
///         - One work per `mint()` call, paid in BNB at exactly `currentPrice()`.
///         - Every work's seed is locked on-chain at mint time, derived from
///           block data. The Eon Engine rule (30 / 54 / 90 / 110 / 150 / 184),
///           era (Fractal / Complex / Chaos / Still) and palette
///           (Signal Lime / Ember Field / Deep Tide) are deterministic
///           functions of that seed, so the website, the gallery and market
///           inspectors can always re-derive exactly how a work is drawn.
///         - The mint ships CLOSED. Deployment does not open it; the owner
///           opens Phase 03 (the mint) explicitly with `setMintOpen(true)`.
///
/// @dev    Caller-type checks (tx.origin / extcodesize) are intentionally NOT
///         used for the agent gate: agentic wallets may themselves be smart
///         wallets, so identity is verified through the Agent ID gate instead
///         of by guessing what kind of account is calling.
contract Eonvera is ERC721, ERC2981, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;

    // ---------------------------------------------------------------------
    // Constants — the collection's fixed shape
    // ---------------------------------------------------------------------

    /// @notice Hard cap. One series, 3,333 works, never increased.
    uint256 public constant MAX_SUPPLY = 3333;

    /// @notice The six Eon Engine laws used by the site's generator.
    uint8 internal constant RULE_0 = 30; // Chaos
    uint8 internal constant RULE_1 = 54; // Complex
    uint8 internal constant RULE_2 = 90; // Fractal
    uint8 internal constant RULE_3 = 110; // Complex
    uint8 internal constant RULE_4 = 150; // Fractal
    uint8 internal constant RULE_5 = 184; // Still

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------

    /// @notice Number of works minted so far. Token IDs are sequential:
    ///         the next mint is always `totalMinted + 1`.
    uint256 public totalMinted;

    /// @notice Current mint price in wei (BNB). Read by agents and by the
    ///         website before minting; `mint()` requires exactly this value.
    uint256 public mintPrice;

    /// @notice The mint starts closed and is opened explicitly by the owner.
    bool public mintOpen;

    /// @notice Where mint proceeds and royalties are received.
    address public treasury;

    /// @notice Optional external Agent ID registry adapter. When set, any
    ///         address it recognises may mint.
    IAgentGate public agentGate;

    /// @notice Owner-managed agent allowlist. An address on this list may
    ///         mint even if no external gate is configured (also the fallback
    ///         used for testing and for the first verified agents).
    mapping(address => bool) public agentAllowlist;

    /// @notice The seed locked on-chain for each minted work.
    mapping(uint256 => uint256) public workSeed;

    string private _baseTokenURI;

    /// @notice Current ERC-2981 default royalty fee in basis points.
    uint96 private _royaltyFee = 500;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Minted(address indexed agent, uint256 indexed tokenId, uint256 seed, uint256 pricePaid);
    event MintOpenChanged(bool open);
    event MintPriceChanged(uint256 newPrice);
    event AgentGateChanged(address indexed gate);
    event AgentAllowed(address indexed agent, bool allowed);
    event TreasuryChanged(address indexed treasury);
    event BaseURIChanged(string baseURI);
    event Withdrawn(address indexed to, uint256 amount);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error MintClosed();
    error NotAnAgent();
    error SoldOut();
    error WrongPayment(uint256 expected, uint256 sent);
    error ZeroAddress();
    error NothingToWithdraw();
    error WithdrawFailed();
    error TokenNotMinted(uint256 tokenId);
    error RoyaltyFeeTooHigh(uint96 fee);

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    /// @param initialOwner  Contract owner (Ownable).
    /// @param treasury_     Receiver of mint proceeds and default royalties.
    /// @param mintPrice_    Initial mint price in wei (BNB).
    /// @param baseURI_      Base metadata URI; tokenURI(id) = baseURI + id.
    constructor(address initialOwner, address treasury_, uint256 mintPrice_, string memory baseURI_)
        ERC721("Eonvera", "EONV")
        Ownable(initialOwner)
    {
        if (treasury_ == address(0)) revert ZeroAddress();
        treasury = treasury_;
        mintPrice = mintPrice_;
        _baseTokenURI = baseURI_;
        // 5% default royalty for secondary markets (ERC-2981), changeable
        // by the owner via setDefaultRoyalty().
        _setDefaultRoyalty(treasury_, 500);
        // NOTE: mintOpen stays false. Deploying never opens the mint.
    }

    // ---------------------------------------------------------------------
    // Mint — agent-only
    // ---------------------------------------------------------------------

    /// @notice Mint exactly one Eonvera work to the calling agent.
    /// @dev    Pays exactly `currentPrice()` in BNB. The work's seed is fixed
    ///         in this block and can never change afterwards.
    /// @return tokenId The minted work's ID (1..3333).
    function mint() external payable nonReentrant whenNotPaused returns (uint256 tokenId) {
        if (!mintOpen) revert MintClosed();
        if (!isAgent(msg.sender)) revert NotAnAgent();
        if (totalMinted >= MAX_SUPPLY) revert SoldOut();

        uint256 price = mintPrice;
        if (msg.value != price) revert WrongPayment(price, msg.value);

        tokenId = totalMinted + 1;
        totalMinted = tokenId;

        uint256 seed = _drawSeed(msg.sender, tokenId);
        workSeed[tokenId] = seed;

        _safeMint(msg.sender, tokenId);

        emit Minted(msg.sender, tokenId, seed, price);
    }

    /// @notice The current mint price in wei — the exact amount `mint()`
    ///         requires. Kept as a function (not just the state variable) so
    ///         agents and the website use the same interface the site was
    ///         built against.
    function currentPrice() public view returns (uint256) {
        return mintPrice;
    }

    /// @notice Works still available to mint.
    function remaining() public view returns (uint256) {
        return MAX_SUPPLY - totalMinted;
    }

    /// @notice Total minted supply (convenience for marketplaces/indexers).
    function totalSupply() public view returns (uint256) {
        return totalMinted;
    }

    // ---------------------------------------------------------------------
    // Agent gate
    // ---------------------------------------------------------------------

    /// @notice True when `account` may mint: it is on the agent allowlist,
    ///         or the configured external Agent ID gate recognises it.
    function isAgent(address account) public view returns (bool) {
        if (agentAllowlist[account]) return true;
        IAgentGate gate = agentGate;
        if (address(gate) != address(0)) {
            // A reverting gate must not lock every agent out of the mint;
            // treat a failed gate call as "not recognised by the gate" and
            // fall back to the allowlist result above.
            try gate.isAgent(account) returns (bool ok) {
                return ok;
            } catch {
                return false;
            }
        }
        return false;
    }

    // ---------------------------------------------------------------------
    // Eon Engine derivation — deterministic views of a work's seed
    // ---------------------------------------------------------------------

    /// @notice The Eon Engine rule a work grows under (30/54/90/110/150/184).
    function workRule(uint256 tokenId) public view returns (uint8) {
        uint256 seed = _seedOf(tokenId);
        uint256 idx = seed % 6;
        if (idx == 0) return RULE_0;
        if (idx == 1) return RULE_1;
        if (idx == 2) return RULE_2;
        if (idx == 3) return RULE_3;
        if (idx == 4) return RULE_4;
        return RULE_5;
    }

    /// @notice Era index of a work: 0 Fractal, 1 Complex, 2 Chaos, 3 Still.
    function workEra(uint256 tokenId) public view returns (uint8) {
        uint8 rule = workRule(tokenId);
        if (rule == 90 || rule == 150) return 0; // Fractal
        if (rule == 54 || rule == 110) return 1; // Complex
        if (rule == 30) return 2; // Chaos
        return 3; // Still (184)
    }

    /// @notice Era name exactly as used on the website.
    function workEraName(uint256 tokenId) public view returns (string memory) {
        uint8 era = workEra(tokenId);
        if (era == 0) return "Fractal";
        if (era == 1) return "Complex";
        if (era == 2) return "Chaos";
        return "Still";
    }

    /// @notice Palette index of a work: 0 Signal Lime, 1 Ember Field,
    ///         2 Deep Tide.
    function workPalette(uint256 tokenId) public view returns (uint8) {
        uint256 seed = _seedOf(tokenId);
        return uint8((seed / 6) % 3);
    }

    /// @notice Palette name exactly as used on the website.
    function workPaletteName(uint256 tokenId) public view returns (string memory) {
        uint8 palette = workPalette(tokenId);
        if (palette == 0) return "Signal Lime";
        if (palette == 1) return "Ember Field";
        return "Deep Tide";
    }

    // ---------------------------------------------------------------------
    // Metadata
    // ---------------------------------------------------------------------

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory base = _baseTokenURI;
        return bytes(base).length > 0 ? string.concat(base, tokenId.toString()) : "";
    }

    // ---------------------------------------------------------------------
    // Owner administration
    // ---------------------------------------------------------------------

    /// @notice Open or close the mint (Roadmap Phase 03).
    function setMintOpen(bool open) external onlyOwner {
        mintOpen = open;
        emit MintOpenChanged(open);
    }

    /// @notice Set the mint price in wei (BNB).
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceChanged(newPrice);
    }

    /// @notice Point the agent gate at the Agent ID registry adapter
    ///         (address(0) disables the external gate).
    function setAgentGate(address gate) external onlyOwner {
        agentGate = IAgentGate(gate);
        emit AgentGateChanged(gate);
    }

    /// @notice Add or remove one agent on the allowlist.
    function setAgentAllowed(address agent, bool allowed) external onlyOwner {
        if (agent == address(0)) revert ZeroAddress();
        agentAllowlist[agent] = allowed;
        emit AgentAllowed(agent, allowed);
    }

    /// @notice Add or remove a batch of agents on the allowlist.
    function setAgentsAllowed(address[] calldata agents, bool allowed) external onlyOwner {
        for (uint256 i = 0; i < agents.length; ++i) {
            if (agents[i] == address(0)) revert ZeroAddress();
            agentAllowlist[agents[i]] = allowed;
            emit AgentAllowed(agents[i], allowed);
        }
    }

    /// @notice Set the base metadata URI.
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
        emit BaseURIChanged(baseURI_);
    }

    /// @notice Set the treasury that receives proceeds and royalties.
    /// @dev    Also updates the ERC-2981 default royalty receiver so the two
    ///         never drift apart; the royalty fee itself is unchanged.
    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert ZeroAddress();
        treasury = treasury_;
        _setDefaultRoyalty(treasury_, _royaltyFee);
        emit TreasuryChanged(treasury_);
    }

    /// @notice Set the default ERC-2981 royalty (fee in basis points of the
    ///         sale price, e.g. 500 = 5%). Receiver is the treasury.
    function setDefaultRoyalty(uint96 feeNumerator) external onlyOwner {
        if (feeNumerator > 10_000) revert RoyaltyFeeTooHigh(feeNumerator);
        _royaltyFee = feeNumerator;
        _setDefaultRoyalty(treasury, feeNumerator);
    }

    /// @notice Pause the mint in an emergency.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resume after a pause.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Withdraw the full BNB balance to the treasury.
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();
        (bool ok,) = treasury.call{value: amount}("");
        if (!ok) revert WithdrawFailed();
        emit Withdrawn(treasury, amount);
    }

    // ---------------------------------------------------------------------
    // Interface support
    // ---------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // ---------------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------------

    /// @dev Seed drawn from block data at mint time — "block-time seed", as
    ///      the website describes. Locked into `workSeed` forever. This seed
    ///      does not guard anything of value (it only drives the artwork), so
    ///      the known predictability of block data is acceptable here; it is
    ///      never used for payments, access or prizes.
    function _drawSeed(address agent, uint256 tokenId) internal view returns (uint256) {
        bytes32 prevBlockHash = block.number > 0 ? blockhash(block.number - 1) : bytes32(0);
        return uint256(keccak256(abi.encode(agent, tokenId, block.timestamp, block.number, prevBlockHash)));
    }

    function _seedOf(uint256 tokenId) internal view returns (uint256) {
        if (tokenId == 0 || tokenId > totalMinted) revert TokenNotMinted(tokenId);
        return workSeed[tokenId];
    }
}
