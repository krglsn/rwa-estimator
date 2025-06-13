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
        token = new RealEstateToken("t.t");
        pool = new Pool(address(token));
        token.setIssuer(address(this));
        pool.setIssuer(address(this));
        token.mint(address(pool), 0, 100, new bytes(0), "test.url");
        token.mint(address(pool), 1, 200, new bytes(0), "test.url");
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
        pool.payRent(49);
        assertTrue(pool.canLiquidate());
        pool.payRent(10);
        assertFalse(pool.canLiquidate());
    }

    function test_safety_amount() public {
        token.setOraclePrice(1, 0, 3);
        token.setOraclePrice(1, 2, 30);
        uint256 expectedSafety = 200 * 30 / 10; // 200 tokens by price 30 and 10% safety
        pool.assign(1, 50, 1 days,  block.timestamp + 100 days);
        assertEq(pool.paymentDeposited(), 200 * 3 / 10);
        vm.warp(block.timestamp + 2 days);
        assertEq(pool.safetyAmount(), expectedSafety);
        assertEq(pool.availableWithdraw(), 0);
    }

    function test_deposit_withdraw() public {
        address depositor = 0xa090437B7c21478F1Cf1615521078204AF66aa7B;
        token.setOraclePrice(1, 0, 40);
        token.setOraclePrice(1, 1, 30);
        token.setOraclePrice(1, 2, 20);
        pool.assign(1, 50, 1 days,  block.timestamp + 100 days);
        assertEq(pool.paymentDeposited(), 800);
        vm.warp(block.timestamp + 1 days);
        assertEq(pool.getPrice(), 30);
        vm.startPrank(depositor);
        pool.deposit(300);
        assertEq(pool.paymentDeposited(), 1100);
        assertEq(token.balanceOf(depositor, 1), 10);
        vm.warp(block.timestamp + 1 days);
        token.setApprovalForAll(address(pool), true);
        pool.withdraw(5);
        assertEq(token.balanceOf(depositor, 1), 5);
        assertEq(pool.paymentDeposited(), 1000);
    }


}