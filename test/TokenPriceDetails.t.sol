pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Issuer} from "../src/Issuer.sol";
import {TokenPriceDetails} from "../src/TokenPriceDetails.sol";
import {Test, console} from "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";

contract IssuerTest is Test {
    TokenPriceDetails public price;
    address public target;

    function setUp() public {
        price = new TokenPriceDetails();
        target = 0x50e646d516fED1371aE363C7d6dc7cA951e82604;
    }

    function test_appraiser() public {
        price.registerAppraiser(target);
        vm.startPrank(target);
        price.setAppraiserPrice(0, 0, 1);
        price.setAppraiserPrice(0, 0, 3);
        (uint256 oracle, uint256 appraisal) = price.getEpochPrice(0, 0);
        vm.stopPrank();
        price.removeAppraiser(target);
        assertEq(appraisal, 2);
    }

    function test_not_allowed_appraiser() public {
        vm.expectRevert(TokenPriceDetails.AppraiserNotAllowed.selector);
        price.setAppraiserPrice(0, 0, 1);
    }

}