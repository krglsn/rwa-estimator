pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";
import {RealEstateToken} from "../src/RealEstateToken.sol";
import {Test, console} from "forge-std/Test.sol";

contract PoolTest is Test {
    RealEstateToken public token;
    Pool public pool;

    function setUp() public {
        vm.warp(block.timestamp + 100 days);
        token = new RealEstateToken("t.t", 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0);
        pool = new Pool(address(token));
        token.setIssuer(address(this));
        pool.setIssuer(address(this));
        vm.deal(address(this), 100 ether);
        token.mint(address(pool), 0, 100, new bytes(0), "test1.url");
        token.mint(address(pool), 1, 200, new bytes(0), "test2.url");
    }

    function test_noplan() public {
        vm.expectRevert(Pool.PlanNotAssigned.selector);
        pool.getPrice();
    }

    function test_assign() public {
        uint256 start = block.timestamp;
        uint256 end = start + 1 days;
        console.log("End time %s", end);
        pool.assign(1, 10, 3600,  end);
        (uint256 epochNumber, uint256 epochEnd) = pool.getEpoch();
        assertEq(epochNumber, 0);
        assertEq(epochEnd, start + 3599);
        assertEq(pool.rentDue(), 10);
        vm.warp(block.timestamp + 130 minutes);
        (uint256 epochNumber2, uint256 epochEnd2) = pool.getEpoch();
        assertEq(epochNumber2, 2);
        assertEq(epochEnd2, start + 3 * 3600 - 1);
        assertEq(pool.rentDue(), 30);
    }

    function test_liquidability() public {
        uint256 start = block.timestamp;
        uint256 end = start + 10 days;
        pool.assign(1, 50, 1 days,  end);
        vm.warp(block.timestamp + 8 hours);
        assertEq(pool.rentDue(), 50);
        assertFalse(pool.canLiquidate());
        vm.warp(block.timestamp + 1 days);
        assertEq(pool.rentDue(), 100);
        assertTrue(pool.canLiquidate());
        pool.payRent{value: 49}(49);
        assertTrue(pool.canLiquidate());
        pool.payRent{value: 10}(10);
        assertFalse(pool.canLiquidate());
    }

    function test_safety_amount() public {
        token.setOraclePrice(1, 0, 3);
        token.setOraclePrice(1, 2, 30);
        uint256 expectedSafety = 200 * 30 / 10; // 200 tokens by price 30 and 10% safety
        pool.assign(1, 50, 1 days,  block.timestamp + 100 days);
        uint256 safetyAmount = pool.safetyAmount();
        pool.paySafety{value: safetyAmount}(safetyAmount);
        assertEq(pool.paymentDeposited(), 200 * 3 / 10);
        vm.warp(block.timestamp + 2 days);
        assertEq(pool.safetyAmount(), expectedSafety);
        assertEq(pool.availableWithdraw(), 0);
    }

    function test_deposit_rounding() public {
        uint256 tokenId = 1;
        address depositor = makeAddr("test_acc");
        vm.deal(depositor, 100 ether);
        token.setOraclePrice(tokenId, 0, 3e18);
        pool.assign(tokenId, 50, 1 days,  block.timestamp + 100 days);
        vm.startPrank(depositor);
        pool.deposit{value: 10 ether}(10 ether);
        assertEq(token.balanceOf(depositor, tokenId), 3);
        assertEq(depositor.balance, 91 ether);
    }

    function test_user_tokens_per_epoch() public {
        uint256 tokenId = 1;
        address depositor = makeAddr("test_acc");
        vm.deal(depositor, 100 ether);
        token.setOraclePrice(tokenId, 0, 3e18);
        token.setOraclePrice(tokenId, 1, 3e18);
        token.setOraclePrice(tokenId, 2, 3e18);
        token.setOraclePrice(tokenId, 3, 3e18);
        pool.assign(tokenId, 50, 1 days,  block.timestamp + 100 days);
        uint256 safety = pool.safetyAmountDue();
        pool.paySafety{value: safety}(safety);
        vm.startPrank(depositor);
        pool.deposit{value: 9 ether}(9 ether);
        assertEq(token.balanceOf(depositor, tokenId), 3);
        vm.warp(block.timestamp + 1 days);
        vm.warp(block.timestamp + 1 days);
        token.setApprovalForAll(address(pool), true);
        pool.withdraw(1);
        assertEq(token.balanceOf(depositor, tokenId), 2);
        assertEq(depositor.balance, 94 ether);
        vm.warp(block.timestamp + 1 days);
        pool.deposit{value: 9 ether}(9 ether);
        vm.warp(block.timestamp + 1 days);
        vm.stopPrank();
        safety = pool.safetyAmountDue();
        pool.paySafety{value: safety}(safety);
        assertEq(pool.getUserBalanceAtEpoch(depositor, 0), 3);
        assertEq(pool.getUserBalanceAtEpoch(depositor, 1), 3);
        assertEq(pool.getUserBalanceAtEpoch(depositor, 2), 2);
        assertEq(pool.getUserBalanceAtEpoch(depositor, 3), 5);
    }

    function test_deposit_withdraw() public {
        address depositor = makeAddr("test_acc");
        vm.deal(depositor, 100 ether);
        token.setOraclePrice(1, 0, 40);
        token.setOraclePrice(1, 1, 30);
        token.setOraclePrice(1, 2, 20);
        pool.assign(1, 50, 1 days,  block.timestamp + 100 days);
        uint256 safety = 800;
        pool.paySafety{value: safety}(safety);
        assertEq(pool.paymentDeposited(), 800);
        vm.warp(block.timestamp + 1 days);
        assertEq(pool.getPrice(), 30);
        vm.startPrank(depositor);
        pool.deposit{value: 300}(300);
        assertEq(pool.paymentDeposited(), 1100);
        assertEq(token.balanceOf(depositor, 1), 10);
        assertEq(address(pool).balance, 1100);
        vm.warp(block.timestamp + 1 days);
        token.setApprovalForAll(address(pool), true);
        pool.withdraw(5);
        assertEq(token.balanceOf(depositor, 1), 5);
        assertEq(pool.paymentDeposited(), 1000);
        assertEq(address(pool).balance, 1000);
    }

    function test_depositor_claim_share() public {
        uint256 tokenId = 0;
        address depositor = makeAddr("test_acc");
        vm.deal(depositor, 100 ether);
        pool.assign(tokenId, 1e16, 1 days,  block.timestamp + 100 days);
        token.setOraclePrice(tokenId, 0, 3e18);
        token.setOraclePrice(tokenId, 1, 3e18);
        vm.prank(depositor);
        pool.deposit{value: 9 ether}(9 ether);
        assertEq(token.balanceOf(depositor, tokenId), 3);
        vm.warp(block.timestamp + 1 days);
        uint256 safety = pool.safetyAmountDue();
        pool.paySafety{value: safety}(safety);
        uint256 rent = pool.rentDue();
        pool.payRent{value: rent}(rent);
        uint256 claimable = pool.canClaimDepositor(depositor);
        // claimable is 3 / 100 tokens for 2 epochs of (1e16 rent minus APPRAISER_REWARD_SHARE) => 3e14
        assertEq(claimable, 3e14);
    }

    function test_claim_equal() public {
        uint256 tokenId = 1;
        token.setPool(tokenId, address(pool));
        pool.assign(tokenId, 50000, 1 days,  block.timestamp + 50 days);
        address a1 = makeAddr("acc1");
        address a2 = makeAddr("acc2");
        token.registerAppraiser(a1);
        token.registerAppraiser(a2);
        for (uint256 i = 0; i < 5; i++) {
            token.setOraclePrice(tokenId, i, 8000);
            vm.prank(a1);
            token.setAppraiserPrice(tokenId, i, 5000);
            vm.prank(a2);
            token.setAppraiserPrice(tokenId, i, 11000);
            assertEq(token.getRewardShare(a1, tokenId, i), 5e17);
        }
        vm.warp(block.timestamp + 5 days);
        assertEq(pool.canClaimAppraiser(a1), 5 * 50000 / (2 * 2));
        assertEq(pool.canClaimAppraiser(a2), 5 * 50000 / (2 * 2));
    }

    function test_claim_proportions() public {
        uint256 tokenId = 1;
        token.setPool(tokenId, address(pool));
        pool.assign(tokenId, 50000, 1 days,  block.timestamp + 50 days);
        address dep = makeAddr("dep");
        address a1 = makeAddr("acc1");
        address a2 = makeAddr("acc2");
        vm.deal(a1, 100 ether);
        vm.deal(a2, 100 ether);
        token.registerAppraiser(a1);
        token.registerAppraiser(a2);
        for (uint256 i = 0; i < 5; i++) {
            token.setOraclePrice(tokenId, i, 8000);
            vm.prank(a1);
            token.setAppraiserPrice(tokenId, i, 3500);
            vm.prank(a2);
            token.setAppraiserPrice(tokenId, i, 10000);
            assertEq(token.getEpochPrice(tokenId, i), 7625);
            assertEq(token.getRewardShare(a1, tokenId, i), 634615384615384615);
            assertEq(token.getRewardShare(a2, tokenId, i), 365384615384615384);
        }
        vm.warp(block.timestamp + 5 days);
        assertEq(pool.canClaimAppraiser(a1), 79325);
        assertEq(pool.canClaimAppraiser(a2), 45670);
        vm.prank(dep);
        vm.deal(dep, 1 ether);
        pool.payRent{value: 250000}(250000);
        uint256 balanceBefore = a1.balance;
        vm.prank(a1);
        vm.expectEmit();
        emit Pool.Claim(a1, 79325);
        pool.claimAppraiser();
        assertEq(pool.canClaimAppraiser(a1), 0);
        uint256 balanceAfter = a1.balance;
        assertGt(balanceAfter, balanceBefore);
        assertEq(balanceAfter - balanceBefore, 79325);
    }

}