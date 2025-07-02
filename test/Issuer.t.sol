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

    function test_program_close() public {
        issuer.issue("close_test", address(pool), 300, 50, 1 days, block.timestamp + 10 days);
        vm.warp(block.timestamp + 10 days);
        uint256 amount = pool.rentDue();
        pool.payRent{value: amount}(amount);
        assertEq(token.balanceOf(address(pool), 0), 300);
        pool.closeProgram();
        assertEq(token.balanceOf(address(pool), 0), 0);
    }

    function test_program_cannot_close_early() public {
        issuer.issue("close_test", address(pool), 300, 50, 1 days, block.timestamp + 10 days);
        vm.warp(block.timestamp + 9 days);
        uint256 amount = pool.rentDue();
        pool.payRent{value: amount}(amount);
        assertEq(token.balanceOf(address(pool), 0), 300);
        vm.expectRevert(Pool.ProgramNotFinished.selector);
        pool.closeProgram();
    }

    function test_program_cannot_close_unpaid() public {
        issuer.issue("close_test", address(pool), 300, 50, 1 days, block.timestamp + 10 days);
        vm.warp(block.timestamp + 11 days);
        uint256 amount = pool.rentDue() - 1;
        pool.payRent{value: amount}(amount);
        assertEq(token.balanceOf(address(pool), 0), 300);
        vm.expectRevert(Pool.RentUnpaid.selector);
        pool.closeProgram();
    }

    function test_program_e2e() public {
        // SETUP
        issuer.issue("e2e-test", address(pool), 1000, 1e6, 1 days, block.timestamp + 5 days);
        address appraiser1 = makeAddr("appraiser1");
        address appraiser2 = makeAddr("appraiser2");
        address depositor1 = makeAddr("depositor1");
        address depositor2 = makeAddr("depositor2");
        address liqui = makeAddr("liquidator");
        vm.deal(depositor1, 10 ether);
        vm.deal(depositor2, 10 ether);
        vm.deal(liqui, 10 ether);

        token.registerAppraiser(appraiser1);
        token.registerAppraiser(appraiser2);

        token.setOraclePrice(0, 0, 1e6);
        token.setOraclePrice(0, 1, 11e5);
        token.setOraclePrice(0, 2, 12e5);
        token.setOraclePrice(0, 3, 11e5);
        token.setOraclePrice(0, 4, 1e6);

        // EPOCH #0
        uint256 rent = pool.rentDue();
        uint256 safety = pool.safetyAmountDue();
        pool.payRent{value: rent}(rent);
        pool.paySafety{value: safety}(safety);
        vm.startPrank(appraiser1);
        token.setAppraiserPrice(0, 0, 12e5);
        token.setAppraiserPrice(0, 1, 12e5);
        vm.stopPrank();
        vm.startPrank(appraiser2);
        token.setAppraiserPrice(0, 0, 1e5);
        token.setAppraiserPrice(0, 1, 1e5);
        vm.stopPrank();

        // EPOCH #1
        vm.warp(block.timestamp + 1 days);
        rent = pool.rentDue();
        safety = pool.safetyAmountDue();
        pool.payRent{value: rent}(rent);
        pool.paySafety{value: safety}(safety);
        vm.startPrank(appraiser1);
        token.setAppraiserPrice(0, 2, 9e5);
        uint256 claim1 = pool.canClaimAppraiser(appraiser1);
        vm.stopPrank();
        vm.startPrank(appraiser2);
        token.setAppraiserPrice(0, 2, 1e5);
        uint256 claim2 = pool.canClaimAppraiser(appraiser2);
        assertGt(claim1, claim2); // a1 set value closer to weighted price, than a2
        pool.claimAppraiser();
        assertEq(pool.canClaimAppraiser(appraiser2), 0);
        vm.stopPrank();
        vm.startPrank(depositor1);
        uint256 price1 = pool.getPrice();
        pool.deposit{value: 100 * price1}(100 * price1);
        assertEq(token.balanceOf(depositor1, 0), 100);
        assertEq(token.balanceOf(address(pool), 0), 900);
        vm.stopPrank();
        rent = pool.rentDue();
        safety = pool.safetyAmountDue();
        pool.payRent{value: rent}(rent);
        pool.paySafety{value: safety}(safety);

        // EPOCH #2
        vm.warp(block.timestamp + 1 days);
        assertFalse(pool.canLiquidate());
        uint256 price2 = pool.getPrice();
        assertGt(price2, price1);
        assertEq(pool.safetyAmountDue(), 0); // have depositor's deposit that covers safety
        vm.startPrank(appraiser1);
        token.setAppraiserPrice(0, 3, 9e5);
        token.setAppraiserPrice(0, 4, 9e5);
        pool.claimAppraiser();
        vm.stopPrank();
        vm.startPrank(appraiser2);
        token.setAppraiserPrice(0, 3, 1e5);
        token.setAppraiserPrice(0, 4, 1e5);
        pool.claimAppraiser();
        assertEq(pool.canClaimAppraiser(appraiser1), 0);
        assertEq(pool.canClaimAppraiser(appraiser2), 0);
        vm.stopPrank();
        vm.startPrank(depositor1);
        token.setApprovalForAll(address(pool), true);
        vm.expectRevert(Pool.NoFundsToWithdraw.selector);
        pool.withdraw(99); // cannot withdraw so much because need increased safety
        pool.withdraw(95);
        vm.stopPrank();
        assertEq(token.balanceOf(depositor1, 0), 5);
        assertEq(token.balanceOf(address(pool), 0), 995);
        vm.startPrank(depositor2);
        uint256 balanceBefore = depositor2.balance;
        uint256 amountD2 = 500 * price2;
        pool.deposit{value: amountD2}(amountD2);
        uint256 balanceAfter = depositor2.balance;
        vm.stopPrank();

        // EPOCH #4
        vm.warp(block.timestamp + 2 days);
        uint256 price3 = pool.getPrice();
        assertLt(price3, price2);
        vm.startPrank(depositor2);
        token.setApprovalForAll(address(pool), true);
        pool.withdraw(500);
        assertEq(token.balanceOf(depositor2, 0), 0);
        assertEq(depositor2.balance, 10 ether - (500 * (price2 - price3))); // loss on price diff between epoch 2 and 4
        pool.claimDepositor();
        assertGt(depositor2.balance, 10 ether - (500 * (price2 - price3)));
        vm.stopPrank();
        assertTrue(pool.canLiquidate());
        uint256 liqAmount = pool.rentDue() + pool.safetyAmountDue();
        vm.startPrank(liqui);
        pool.liquidate{value: liqAmount}();
        uint256 withdrawable1 = pool.availableWithdraw();
        pool.withdrawOwner(withdrawable1 - 10);
        vm.stopPrank();
        assertFalse(pool.canLiquidate());

        // EPOCH #5 END OF PROGRAM
        vm.warp(block.timestamp + 1 days);
        assertEq(pool.availableWithdraw(), 10);
        vm.startPrank(liqui);
        vm.expectRevert(Pool.ProgramFinished.selector);
        pool.withdrawOwner(1);
        assertEq(pool.safetyAmountDue(), 0);
        vm.stopPrank();
        vm.expectRevert(Pool.NotAssetOwner.selector);
        pool.closeProgram();
        vm.startPrank(liqui);
        vm.expectRevert(Pool.RentUnpaid.selector);
        pool.closeProgram();
        pool.payRent{value: pool.rentDue()}(pool.rentDue());
        pool.closeProgram();
        assertEq(token.balanceOf(address(pool), 0), 0);
        vm.stopPrank();
    }
}
