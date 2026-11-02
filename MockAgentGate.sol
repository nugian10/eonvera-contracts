// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Test/example stand-in for an Agent ID registry adapter.
/// @dev    NOT for production. A real adapter would verify Agent ID ownership
///         against the actual registry used at launch (e.g. the Agent ID
///         system behind the Binance Agentic Wallet flow). This mock simply
///         keeps its own set so the Eonvera gate logic can be tested locally.
contract MockAgentGate {
    mapping(address => bool) public agents;

    function setAgent(address account, bool ok) external {
        agents[account] = ok;
    }

    function isAgent(address account) external view returns (bool) {
        return agents[account];
    }
}

/// @notice A gate whose isAgent() always reverts — used to prove the Eonvera
///         allowlist still works while an external gate is broken.
contract RevertingAgentGate {
    function isAgent(address) external pure returns (bool) {
        revert("gate down");
    }
}
