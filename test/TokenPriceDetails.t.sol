pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Issuer} from "../src/Issuer.sol";
import {TokenPriceDetails} from "../src/TokenPriceDetails.sol";
import {Test, console} from "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";

contract TokenPriceDetailsTestFacade is TokenPriceDetails {
    function call_setAppraiserPrice(uint256 tokenId, uint256 epochId, uint256 appraisal) external {
        _setAppraiserPrice(tokenId, epochId, appraisal);
    }
}

contract IssuerTest is Test {
    TokenPriceDetailsTestFacade public facade;
    address public target;

    function setUp() public {
        facade = new TokenPriceDetailsTestFacade();
        target = 0x50e646d516fED1371aE363C7d6dc7cA951e82604;
    }

    function test_appraiser() public {
        facade.registerAppraiser(target);
        vm.startPrank(target);
        facade.call_setAppraiserPrice(0, 0, 1);
        facade.call_setAppraiserPrice(0, 0, 3);
        (uint256 oracle, uint256 appraisal) = facade.getEpochPrice(0, 0);
        vm.stopPrank();
        facade.removeAppraiser(target);
        assertEq(appraisal, 2);
    }

    function test_notAllowedAppraiser() public {
        vm.expectRevert( abi.encodeWithSelector(TokenPriceDetails.AppraiserNotAllowed.selector, address(this)));
        facade.call_setAppraiserPrice(0, 0, 1);
    }

    function test_noPool() public {
        facade.registerAppraiser(target);
        vm.startPrank(target);
        vm.expectRevert(TokenPriceDetails.PoolNotSet.selector);
        facade.setAppraiserPrice(0, 0, 1);
    }

}