// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Eonvera} from "../Eonvera.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @notice Test stand-in for a smart-contract agent wallet (the shape an
///         agentic wallet can take). Proves that a contract-based agent that
///         is allowlisted / gate-verified can mint and safely receive the NFT
///         via _safeMint — the Eonvera gate checks Agent ID identity, never
///         the caller type.
/// @dev    Test-only, NOT for production.
contract AgentWallet is IERC721Receiver {
    function mint(Eonvera nft, uint256 price) external returns (uint256) {
        return nft.mint{value: price}();
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
