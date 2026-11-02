// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Eonvera} from "../contracts/Eonvera.sol";

/// @notice Full launch rehearsal on a LOCAL EVM using the real launch
///         parameters and the real wallet addresses from launch-params.md.
///         Nothing here touches a live network: balances are dealt locally
///         and calls are pranked, purely to prove the launch sequence works
///         end-to-end with the exact addresses that will be used for real.
contract LaunchRehearsalTest is Test {
    // Real addresses (launch-params.md, decided 2026-11-03)
    address internal constant OWNER = 0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097;
    address internal constant AGENTIC = 0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7;
    uint256 internal constant PRICE = 300000000000000; // 0.0003 BNB
    string internal constant BASE_URI = "https://eonvera.vercel.app/metadata/";

    Eonvera internal nft;

    function setUp() public {
        nft = new Eonvera(OWNER, AGENTIC, PRICE, BASE_URI);
    }

    function test_LaunchSequenceWithRealParams() public {
        // 1. Fresh deploy state: owner/treasury/price correct, mint closed.
        assertEq(nft.owner(), OWNER);
        assertEq(nft.treasury(), AGENTIC);
        assertEq(nft.currentPrice(), PRICE);
        assertFalse(nft.mintOpen());
        assertEq(nft.MAX_SUPPLY(), 3333);

        // 2. Owner registers the Agentic Wallet as the first verified agent
        //    (allowlist path; the registry gate can be attached later) and
        //    opens the mint.
        vm.startPrank(OWNER);
        nft.setAgentAllowed(AGENTIC, true);
        nft.setMintOpen(true);
        vm.stopPrank();

        // 3. The Agentic Wallet mints work #1 paying exactly 0.0003 BNB.
        vm.deal(AGENTIC, 1 ether);
        vm.prank(AGENTIC);
        uint256 id = nft.mint{value: PRICE}();
        assertEq(id, 1);
        assertEq(nft.ownerOf(1), AGENTIC);
        assertEq(address(nft).balance, PRICE);

        // 4. The work's on-chain identity resolves for gallery/market:
        //    seed non-zero, rule in the Eon Engine set, era/palette named.
        assertTrue(nft.workSeed(1) != 0);
        uint8 rule = nft.workRule(1);
        assertTrue(rule == 30 || rule == 54 || rule == 90 || rule == 110 || rule == 150 || rule == 184);
        assertTrue(bytes(nft.workEraName(1)).length > 0);
        assertTrue(bytes(nft.workPaletteName(1)).length > 0);
        assertEq(nft.tokenURI(1), "https://eonvera.vercel.app/metadata/1");

        // 5. Royalties point at the Agentic Wallet treasury (5% default).
        (address receiver, uint256 royalty) = nft.royaltyInfo(1, 1 ether);
        assertEq(receiver, AGENTIC);
        assertEq(royalty, 0.05 ether);

        // 6. Owner withdraws: the full mint revenue lands in the Agentic
        //    Wallet (treasury), exactly as planned.
        uint256 treasuryBefore = AGENTIC.balance;
        vm.prank(OWNER);
        nft.withdraw();
        assertEq(address(nft).balance, 0);
        assertEq(AGENTIC.balance, treasuryBefore + PRICE);

        // 7. Strangers still cannot mint, even with the mint open.
        address stranger = makeAddr("stranger");
        vm.deal(stranger, 1 ether);
        vm.prank(stranger);
        vm.expectRevert(Eonvera.NotAnAgent.selector);
        nft.mint{value: PRICE}();
    }
}
