pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Issuer} from "../src/Issuer.sol";
import {RealEstateToken} from "../src/RealEstateToken.sol";
import {TokenPriceDetails} from "../src/TokenPriceDetails.sol";
import {Test, console} from "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";

contract IssuerTest is Test {
    Issuer public issuer;
    RealEstateToken public token;
    Pool public pool;

    function setUp() public {
        token = new RealEstateToken("t.t", 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0);
        console.log("Token %s", address(token));
        pool = new Pool(address(token));
        console.log("Pool %s", address(pool));
        issuer = new Issuer(address(token));
        console.log("Issuer %s", address(issuer));
        token.setIssuer(address(issuer));
        pool = new Pool(address(token));
        pool.setIssuer(address(issuer));
    }

    function test_issue() public {
        assertFalse(token.exists(0));
        issuer.issue("test.url", address(pool), 100, 1, 3600, 1907577068);
        assertTrue(token.exists(0));
        uint256 balance = token.balanceOf(address(pool), 0);
        assertEq(balance, 100);
        assertFalse(token.exists(1));
        Pool pool2 = new Pool(address(token));
        pool2.setIssuer(address(issuer));
        uint256 id = issuer.issue("test2.url", address(pool2), 200, 1, 3600, 1907577068);
        assertEq(id, 1);
        assertTrue(token.exists(1));
        balance = token.balanceOf(address(pool2), 1);
        assertEq(balance, 200);
        assertEq(200, token.totalSupply(1));
    }

    function test_poolAssignment() public {
        assertFalse(token.exists(0));
        issuer.issue("another_test", address(pool), 111, 11, 32, 1907577068);
        Pool.UsagePlan memory plan = pool.getPlan();
        assertEq(plan.rentAmount, 11);
        assertEq(plan.epochDuration, 32);
        assertEq(plan.programEnd, 1907577068);
    }

    function test_shortEpoch() public {
        assertFalse(token.exists(0));
        vm.expectRevert(Pool.TooShortEpoch.selector);
        issuer.issue("another_test", address(pool), 111, 11, 22, 1907577068);
    }

    function test_lockAppraisal() public {
        assertFalse(token.exists(0));
        uint256 tokenId = issuer.issue("another_test", address(pool), 111, 11, 32, 1907577068);
        token.setIssuer(address(this));
        token.registerAppraiser(address(this));
        vm.warp(block.timestamp + 10);
        vm.expectRevert();
        token.setAppraiserPrice(tokenId, 0, 1);
    }

    function test_duplicatedAppraisal() public {
        assertFalse(token.exists(0));
        uint256 tokenId = issuer.issue("another_test", address(pool), 111, 11, 32, 1907577068);
        token.setIssuer(address(this));
        token.registerAppraiser(address(this));
        token.setAppraiserPrice(tokenId, 0, 1);
        vm.expectRevert(TokenPriceDetails.AppraisalAlreadySet.selector);
        token.setAppraiserPrice(tokenId, 0, 2);
    }

    function test_liquidation() public {
        address oldOwner = address(this);
        uint256 tokenId = issuer.issue("another_test", address(pool), 300, 50, 1 days, 1907577068);
        vm.warp(block.timestamp + 8 hours);
        assertEq(pool.rentDue(), 50);
        assertFalse(pool.canLiquidate());
        vm.warp(block.timestamp + 1 days);
        assertEq(pool.rentDue(), 100);
        assertTrue(pool.canLiquidate());
        pool.payRent{value: 49}(49);
        assertTrue(pool.canLiquidate());
        uint256 rent = pool.rentDue();
        uint256 safety = pool.safetyAmountDue();
        address liquidator = makeAddr("liqui");
        vm.deal(liquidator, 10e18);
        vm.prank(liquidator);
        vm.expectEmit();
        emit Pool.Liquidation(oldOwner, liquidator);
        pool.liquidate{value: rent + safety}();
        assertTrue(token.isAssetOwner(tokenId, liquidator));
    }

    function test_liquidation_lowpayment() public {
        issuer.issue("another_test", address(pool), 300, 50, 1 days, 1907577068);
        vm.warp(block.timestamp + 8 hours);
        assertEq(pool.rentDue(), 50);
        assertFalse(pool.canLiquidate());
        vm.warp(block.timestamp + 1 days);
        assertEq(pool.rentDue(), 100);
        assertTrue(pool.canLiquidate());
        pool.payRent{value: 49}(49);
        assertTrue(pool.canLiquidate());
        uint256 rent = pool.rentDue();
        uint256 safety = pool.safetyAmountDue();
        address liquidator = makeAddr("liqui");
        vm.deal(liquidator, 10e18);
        vm.prank(liquidator);
        vm.expectRevert(Pool.LowLiquidationPayment.selector);
        pool.liquidate{value: rent + safety - 1}();
    }

    function test_noliquidation() public {
        issuer.issue("another_test", address(pool), 300, 50, 1 days, 1907577068);
        vm.warp(block.timestamp + 8 hours);
        assertEq(pool.rentDue(), 50);
        assertFalse(pool.canLiquidate());
        vm.warp(block.timestamp + 1 days);
        assertEq(pool.rentDue(), 100);
        assertTrue(pool.canLiquidate());
        pool.payRent{value: 100}(100);
        assertFalse(pool.canLiquidate());
        uint256 rent = pool.rentDue();
        uint256 safety = pool.safetyAmountDue();
        address liquidator = makeAddr("liqui");
        vm.deal(liquidator, 10e18);
        vm.prank(liquidator);
        vm.expectRevert(Pool.CannotLiquidate.selector);
        pool.liquidate{value: rent + safety}();
    }
}
