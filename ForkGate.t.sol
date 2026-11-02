// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SpaceIdAgentGate} from "../contracts/SpaceIdAgentGate.sol";
import {Eonvera} from "../contracts/Eonvera.sol";

/// @notice MAINNET FORK tests — run only with a fork URL:
///         forge test --fork-url https://bsc-dataseed.binance.org --match-contract ForkGateTest
///         They consult the REAL SPACE ID Agent ID collection and the REAL
///         launch wallets, proving the public mint path end to end.
contract ForkGateTest is Test {
    /// @dev SPACE ID Agent ID collection, BNB Chain mainnet (name "SPACE ID Agent ID", symbol "AI").
    address internal constant AGENT_ID_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    /// @dev The project's Binance Agentic Wallet (treasury) — holds a claimed Agent ID.
    address internal constant AGENTIC_WALLET = 0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7;
    /// @dev The project's personal owner wallet — holds no Agent ID.
    address internal constant OWNER_WALLET = 0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097;

    SpaceIdAgentGate internal gate;

    function setUp() public {
        // Without a mainnet fork the registry address holds no code; skip
        // instead of failing so the plain `forge test` suite stays green.
        if (AGENT_ID_REGISTRY.code.length == 0) vm.skip(true);
        gate = new SpaceIdAgentGate(AGENT_ID_REGISTRY);
    }

    function test_realRegistry_agenticWalletIsAgent() public view {
        assertTrue(gate.isAgent(AGENTIC_WALLET));
    }

    function test_realRegistry_ownerWalletIsNotAgent() public view {
        assertFalse(gate.isAgent(OWNER_WALLET));
    }

    /// @notice The decisive rehearsal: a fresh Eonvera wired to the public
    ///         gate accepts a mint from the real Agentic Wallet (impersonated
    ///         by the fork) and rejects the personal wallet — exactly the
    ///         behaviour the public launch needs.
    function test_forkMintThroughPublicGate() public {
        Eonvera eonvera = new Eonvera(OWNER_WALLET, AGENTIC_WALLET, 0.0003 ether, "");
        vm.prank(OWNER_WALLET);
        eonvera.setAgentGate(address(gate));
        vm.prank(OWNER_WALLET);
        eonvera.setMintOpen(true);

        vm.deal(AGENTIC_WALLET, 1 ether);
        vm.prank(AGENTIC_WALLET);
        eonvera.mint{value: 0.0003 ether}();
        assertEq(eonvera.ownerOf(1), AGENTIC_WALLET);

        vm.deal(OWNER_WALLET, 1 ether);
        vm.prank(OWNER_WALLET);
        vm.expectRevert(Eonvera.NotAnAgent.selector);
        eonvera.mint{value: 0.0003 ether}();
    }
}
