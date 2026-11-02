// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Eonvera, IAgentGate} from "../contracts/Eonvera.sol";
import {MockAgentGate, RevertingAgentGate} from "../contracts/mocks/MockAgentGate.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EonveraTest is Test {
    Eonvera internal nft;
    MockAgentGate internal gate;

    address internal owner = makeAddr("owner");
    address internal treasury = makeAddr("treasury");
    address internal agent = makeAddr("agent");
    address internal agent2 = makeAddr("agent2");
    address internal stranger = makeAddr("stranger");

    // Official mint price decided by the project owner (2026-11-03):
    // 0.0003 BNB = 300000000000000 wei.
    uint256 internal constant PRICE = 0.0003 ether;

    function setUp() public {
        nft = new Eonvera(owner, treasury, PRICE, "ipfs://eonvera/");
        gate = new MockAgentGate();
        vm.deal(agent, 100 ether);
        vm.deal(agent2, 100 ether);
        vm.deal(stranger, 100 ether);
    }

    // -- helpers -----------------------------------------------------------

    function _openWithAllowlist() internal {
        vm.startPrank(owner);
        nft.setAgentAllowed(agent, true);
        nft.setMintOpen(true);
        vm.stopPrank();
    }

    function _mintAs(address who) internal returns (uint256) {
        vm.prank(who);
        return nft.mint{value: PRICE}();
    }

    // -- collection shape --------------------------------------------------

    function test_CollectionShape() public view {
        assertEq(nft.name(), "Eonvera");
        assertEq(nft.symbol(), "EONV");
        assertEq(nft.MAX_SUPPLY(), 3333);
        assertEq(nft.totalMinted(), 0);
        assertEq(nft.remaining(), 3333);
        assertEq(nft.currentPrice(), PRICE);
        assertEq(nft.treasury(), treasury);
    }

    function test_MintShipsClosed() public {
        vm.prank(owner);
        nft.setAgentAllowed(agent, true);
        // mintOpen was never enabled
        vm.prank(agent);
        vm.expectRevert(Eonvera.MintClosed.selector);
        nft.mint{value: PRICE}();
    }

    // -- agent gate ---------------------------------------------------------

    function test_NonAgentCannotMint() public {
        vm.prank(owner);
        nft.setMintOpen(true);
        vm.prank(stranger);
        vm.expectRevert(Eonvera.NotAnAgent.selector);
        nft.mint{value: PRICE}();
    }

    function test_AllowlistedAgentCanMint() public {
        _openWithAllowlist();
        uint256 id = _mintAs(agent);
        assertEq(id, 1);
        assertEq(nft.ownerOf(1), agent);
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.remaining(), 3332);
        assertTrue(nft.workSeed(1) != 0);
    }

    function test_GateAgentCanMintWithoutAllowlist() public {
        gate.setAgent(agent2, true);
        vm.startPrank(owner);
        nft.setAgentGate(address(gate));
        nft.setMintOpen(true);
        vm.stopPrank();
        assertTrue(nft.isAgent(agent2));
        uint256 id = _mintAs(agent2);
        assertEq(nft.ownerOf(id), agent2);
    }

    function test_BrokenGateFallsBackToAllowlist() public {
        RevertingAgentGate bad = new RevertingAgentGate();
        vm.startPrank(owner);
        nft.setAgentGate(address(bad));
        nft.setAgentAllowed(agent, true);
        nft.setMintOpen(true);
        vm.stopPrank();
        // gate reverts internally; isAgent must not bubble the revert
        assertTrue(nft.isAgent(agent));
        assertFalse(nft.isAgent(stranger));
        uint256 id = _mintAs(agent);
        assertEq(id, 1);
    }

    function test_RemovedAgentCannotMint() public {
        _openWithAllowlist();
        vm.prank(owner);
        nft.setAgentAllowed(agent, false);
        vm.prank(agent);
        vm.expectRevert(Eonvera.NotAnAgent.selector);
        nft.mint{value: PRICE}();
    }

    // -- payment ------------------------------------------------------------

    function test_WrongPaymentReverts() public {
        _openWithAllowlist();
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(Eonvera.WrongPayment.selector, PRICE, PRICE - 1));
        nft.mint{value: PRICE - 1}();
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(Eonvera.WrongPayment.selector, PRICE, PRICE + 1));
        nft.mint{value: PRICE + 1}();
    }

    function test_OwnerCanChangePrice() public {
        vm.prank(owner);
        nft.setMintPrice(0.1 ether);
        assertEq(nft.currentPrice(), 0.1 ether);
    }

    // -- seed / rule / era / palette ----------------------------------------

    function test_EngineDerivationIsConsistent() public {
        _openWithAllowlist();
        vm.deal(agent, 10000 ether);
        // mint a batch and check every derived value stays inside the
        // site's vocabulary and matches the rule -> era mapping
        for (uint256 i = 0; i < 60; i++) {
            uint256 id = _mintAs(agent);
            uint8 rule = nft.workRule(id);
            assertTrue(
                rule == 30 || rule == 54 || rule == 90 || rule == 110 || rule == 150 || rule == 184,
                "rule outside Eon Engine set"
            );
            string memory era = nft.workEraName(id);
            if (rule == 90 || rule == 150) assertEq(era, "Fractal");
            if (rule == 54 || rule == 110) assertEq(era, "Complex");
            if (rule == 30) assertEq(era, "Chaos");
            if (rule == 184) assertEq(era, "Still");
            uint8 palette = nft.workPalette(id);
            assertTrue(palette <= 2);
            string memory p = nft.workPaletteName(id);
            assertTrue(
                keccak256(bytes(p)) == keccak256("Signal Lime") || keccak256(bytes(p)) == keccak256("Ember Field")
                    || keccak256(bytes(p)) == keccak256("Deep Tide")
            );
            // same seed must always derive the same values
            assertEq(nft.workRule(id), rule);
        }
    }

    function test_UnmintedWorkViewsRevert() public {
        vm.expectRevert(abi.encodeWithSelector(Eonvera.TokenNotMinted.selector, 7));
        nft.workRule(7);
        vm.expectRevert(abi.encodeWithSelector(Eonvera.TokenNotMinted.selector, 0));
        nft.workEraName(0);
    }

    // -- supply cap -----------------------------------------------------------

    function test_SoldOutAt3333() public {
        _openWithAllowlist();
        vm.deal(agent, 10000 ether);
        for (uint256 i = 0; i < 3333; i++) {
            _mintAs(agent);
        }
        assertEq(nft.totalMinted(), 3333);
        assertEq(nft.remaining(), 0);
        assertEq(nft.ownerOf(3333), agent);
        vm.prank(agent);
        vm.expectRevert(Eonvera.SoldOut.selector);
        nft.mint{value: PRICE}();
    }

    // -- admin safety ---------------------------------------------------------

    function test_OnlyOwnerAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        nft.setMintOpen(true);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        nft.setMintPrice(1);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        nft.setAgentAllowed(agent, true);
    }

    function test_PauseBlocksMint() public {
        _openWithAllowlist();
        vm.prank(owner);
        nft.pause();
        vm.prank(agent);
        vm.expectRevert(); // Pausable.EnforcedPause
        nft.mint{value: PRICE}();
        vm.prank(owner);
        nft.unpause();
        uint256 id = _mintAs(agent);
        assertEq(id, 1);
    }

    // -- money ------------------------------------------------------------------

    function test_WithdrawGoesToTreasury() public {
        _openWithAllowlist();
        _mintAs(agent);
        _mintAs(agent);
        assertEq(address(nft).balance, PRICE * 2);
        uint256 before = treasury.balance;
        vm.prank(owner);
        nft.withdraw();
        assertEq(address(nft).balance, 0);
        assertEq(treasury.balance, before + PRICE * 2);
        vm.prank(owner);
        vm.expectRevert(Eonvera.NothingToWithdraw.selector);
        nft.withdraw();
    }

    // -- market readiness ---------------------------------------------------------

    function test_TransferAndRoyalty() public {
        _openWithAllowlist();
        uint256 id = _mintAs(agent);
        // owner can transfer the work (secondary market readiness)
        vm.prank(agent);
        nft.transferFrom(agent, stranger, id);
        assertEq(nft.ownerOf(id), stranger);
        // ERC-2981 default royalty: 5% to treasury
        (address receiver, uint256 amount) = nft.royaltyInfo(id, 1 ether);
        assertEq(receiver, treasury);
        assertEq(amount, 0.05 ether);
    }

    function test_TokenURI() public {
        _openWithAllowlist();
        uint256 id = _mintAs(agent);
        assertEq(nft.tokenURI(id), "ipfs://eonvera/1");
    }
}
