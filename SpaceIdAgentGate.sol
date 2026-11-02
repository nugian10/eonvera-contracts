// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal read interface of the SPACE ID Agent ID collection (ERC-721 style).
interface ISpaceIdAgentId {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title  SpaceIdAgentGate — Eonvera's public Agent ID gate adapter
/// @notice Implements Eonvera's `IAgentGate`. An account is an agent iff it
///         holds at least one SPACE ID Agent ID — the soulbound `.ai` name NFT
///         that Binance Agentic Wallet users claim in the Binance Wallet app.
///
///         Collection: "SPACE ID Agent ID" (symbol "AI") on BNB Chain (56):
///         0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
///         (verified on-chain 2026-11-03: name()/symbol() read from the live
///         contract; the same address + balanceOf check is used by Nomio-style
///         agent-gated mints across the ecosystem.)
///
///         The registry address is an immutable constructor argument: deploy
///         with the address above. If SPACE ID ever migrates the collection,
///         deploy a new adapter and point Eonvera's `setAgentGate` at it —
///         the Eonvera owner allowlist remains as a fallback either way.
contract SpaceIdAgentGate {
    /// @notice The SPACE ID Agent ID collection this gate consults.
    ISpaceIdAgentId public immutable agentIdRegistry;

    error ZeroRegistry();

    constructor(address registry) {
        if (registry == address(0)) revert ZeroRegistry();
        agentIdRegistry = ISpaceIdAgentId(registry);
    }

    /// @notice True iff `account` holds a SPACE ID Agent ID (balance > 0).
    ///         A registry that errors reads as "not an agent" here; Eonvera
    ///         additionally falls back to its owner allowlist if a gate call
    ///         itself were to fail.
    function isAgent(address account) external view returns (bool) {
        try agentIdRegistry.balanceOf(account) returns (uint256 balance) {
            return balance > 0;
        } catch {
            return false;
        }
    }
}
