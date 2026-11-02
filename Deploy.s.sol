// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Eonvera} from "../contracts/Eonvera.sol";

/// @notice Deploy Eonvera with the official launch parameters.
/// @dev    Defaults below ARE the decided launch params (launch-params.md).
///         They can be overridden with env vars: OWNER, TREASURY,
///         MINT_PRICE_WEI, BASE_URI.
///
///         This script is only ever run with an explicit broadcast command
///         and a signer the project owner controls, e.g.:
///
///         forge script script/Deploy.s.sol --rpc-url bsc \
///             --broadcast --private-key <OWNER_KEY>
///
///         The mint deploys CLOSED. Opening it is a separate, deliberate
///         transaction (`setMintOpen(true)`) after checks pass.
contract Deploy is Script {
    // Decided 2026-11-03 — see launch-params.md
    address internal constant DEFAULT_OWNER = 0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097;
    address internal constant DEFAULT_TREASURY = 0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7;
    uint256 internal constant DEFAULT_PRICE_WEI = 300000000000000; // 0.0003 BNB

    function run() external returns (Eonvera nft) {
        address owner_ = vm.envOr("OWNER", DEFAULT_OWNER);
        address treasury_ = vm.envOr("TREASURY", DEFAULT_TREASURY);
        uint256 price_ = vm.envOr("MINT_PRICE_WEI", DEFAULT_PRICE_WEI);
        // Base URI is intentionally NOT defaulted to a real value: metadata
        // location is still an open launch decision. For a rehearsal pass
        // BASE_URI explicitly; for production set the final URI.
        string memory baseURI_ = vm.envOr("BASE_URI", string(""));

        vm.startBroadcast();
        nft = new Eonvera(owner_, treasury_, price_, baseURI_);
        vm.stopBroadcast();
    }
}
