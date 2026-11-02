// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SpaceIdAgentGate} from "../contracts/SpaceIdAgentGate.sol";
import {Eonvera} from "../contracts/Eonvera.sol";

/// @dev Stand-in for the SPACE ID Agent ID collection.
contract MockAgentIdRegistry {
    mapping(address => uint256) public balances;
    bool public broken;

    function setBalance(address account, uint256 value) external {
        balances[account] = value;
    }

    function setBroken(bool value) external {
        broken = value;
    }

    function balanceOf(address account) external view returns (uint256) {
        require(!broken, "registry broken");
        return balances[account];
    }
}

contract SpaceIdAgentGateTest is Test {
    address internal constant HOLDER = address(0xA6E77);
    address internal constant STRANGER = address(0x57A9);

    MockAgentIdRegistry internal registry;
    SpaceIdAgentGate internal gate;

    function setUp() public {
        registry = new MockAgentIdRegistry();
        gate = new SpaceIdAgentGate(address(registry));
    }

    function test_holderIsAgent() public {
        registry.setBalance(HOLDER, 1);
        assertTrue(gate.isAgent(HOLDER));
    }

    function test_strangerIsNotAgent() public view {
        assertFalse(gate.isAgent(STRANGER));
    }

    function test_brokenRegistryReadsAsNotAgent() public {
        registry.setBalance(HOLDER, 1);
        registry.setBroken(true);
        assertFalse(gate.isAgent(HOLDER));
    }

    function test_zeroRegistryReverts() public {
        vm.expectRevert(SpaceIdAgentGate.ZeroRegistry.selector);
        new SpaceIdAgentGate(address(0));
    }

    /// @notice End-to-end with a locally deployed Eonvera: once the owner
    ///         points the collection at this gate, Agent ID holders can mint
    ///         and everyone else is rejected — no allowlist entries involved.
    function test_eonveraMintThroughGate() public {
        address owner = address(0x0B1E2);
        address treasury = address(0x7EA5);
        Eonvera eonvera = new Eonvera(owner, treasury, 0.0003 ether, "");
        vm.prank(owner);
        eonvera.setAgentGate(address(gate));
        vm.prank(owner);
        eonvera.setMintOpen(true);

        registry.setBalance(HOLDER, 1);
        vm.deal(HOLDER, 1 ether);
        vm.prank(HOLDER);
        eonvera.mint{value: 0.0003 ether}();
        assertEq(eonvera.ownerOf(1), HOLDER);
        assertEq(eonvera.totalMinted(), 1);

        vm.deal(STRANGER, 1 ether);
        vm.prank(STRANGER);
        vm.expectRevert(Eonvera.NotAnAgent.selector);
        eonvera.mint{value: 0.0003 ether}();
    }
}
