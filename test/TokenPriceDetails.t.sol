pragma solidity 0.8.24;

import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {Pool} from "../src/Pool.sol";
import {TokenPriceDetails} from "../src/TokenPriceDetails.sol";
import {MockPool, TokenPriceDetailsTestFacade} from "./TokenPriceDetails.t.sol";

contract TokenPriceDetailsTestFacade is TokenPriceDetails {
    mapping(uint256 => MockPool) private _mockPools;

    constructor() TokenPriceDetails(0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0) {}

    function call_setAppraiserPrice(uint256 tokenId, uint256 epochId, uint256 appraisal) external {
        _setAppraiserPrice(tokenId, epochId, appraisal);
    }

    function call_getAverageAppraisal(uint256 tokenId, uint256 epochId) external view returns (uint256) {
        return _getAverageAppraisal(tokenId, epochId);
    }

    function setupMockPool(uint256 tokenId, uint256 epochNumber, uint256 epochEndTime) external {
        if (address(_mockPools[tokenId]) == address(0)) {
            _mockPools[tokenId] = new MockPool(epochNumber, epochEndTime);
        } else {
            _mockPools[tokenId].setEpochValues(epochNumber, epochEndTime);
        }
        setPool(tokenId, address(_mockPools[tokenId]));
    }

    function call_fulfillRequest(bytes32 a, bytes memory b, bytes memory c) external {
        fulfillRequest(a, b, c);
    }
}

contract MockPool {
    uint256 private _epochNumber;
    uint256 private _epochEndTime;

    constructor(uint256 epochNumber_, uint256 epochEndTime_) {
        _epochNumber = epochNumber_;
        _epochEndTime = epochEndTime_;
    }

    function getEpoch() external view returns (uint256 epochNumber, uint256 epochEndTime) {
        return (_epochNumber, _epochEndTime);
    }

    function setEpochValues(uint256 epochNumber_, uint256 epochEndTime_) external {
        _epochNumber = epochNumber_;
        _epochEndTime = epochEndTime_;
    }
}

contract IssuerTest is Test {
    TokenPriceDetailsTestFacade public facade;
    address public target;
    TokenPriceDetails public token;

    function setUp() public {
        facade = new TokenPriceDetailsTestFacade();
        facade.setIssuer(address(this));
        target = makeAddr("test_acc");
    }

    function test_appraiser() public {
        facade.registerAppraiser(target);
        facade.setOraclePrice(0, 0, 30);
        vm.startPrank(target);
        facade.call_setAppraiserPrice(0, 0, 70);
        facade.call_setAppraiserPrice(0, 1, 3);
        uint256 price = facade.getEpochPrice(0, 0);
        vm.stopPrank();
        facade.removeAppraiser(target);
        assertEq(price, 42);
    }

    function test_averageAppraisal() public {
        facade.registerAppraiser(target);
        facade.registerAppraiser(address(this));
        facade.call_setAppraiserPrice(0, 0, 1);
        facade.call_setAppraiserPrice(0, 5, 10);
        facade.call_setAppraiserPrice(0, 6, 1000);
        vm.startPrank(target);
        facade.call_setAppraiserPrice(0, 0, 3);
        facade.call_setAppraiserPrice(0, 5, 3);
        assertEq(facade.call_getAverageAppraisal(0, 0), 2);
        assertEq(facade.getAppraisalCount(0, 0), 2);
        assertEq(facade.call_getAverageAppraisal(0, 5), 6);
        assertEq(facade.getAppraisalCount(0, 5), 2);
        assertEq(facade.call_getAverageAppraisal(0, 6), 1000);
        assertEq(facade.getAppraisalCount(0, 6), 1);
        assertEq(facade.call_getAverageAppraisal(0, 7), 0);
        assertEq(facade.getAppraisalCount(0, 7), 0);
    }

    function test_notAllowedAppraiser() public {
        vm.expectRevert(abi.encodeWithSelector(TokenPriceDetails.AppraiserNotAllowed.selector, address(this)));
        facade.call_setAppraiserPrice(0, 0, 1);
    }

    function test_noPool() public {
        facade.registerAppraiser(target);
        vm.startPrank(target);
        vm.expectRevert(TokenPriceDetails.PoolNotSet.selector);
        facade.setAppraiserPrice(0, 0, 1);
        vm.stopPrank();
    }

    function test_shares() public {
        address appraiser1 = makeAddr("appraiser1");
        address appraiser2 = makeAddr("appraiser2");
        facade.setOraclePrice(0, 0, 2000);
        facade.registerAppraiser(address(appraiser1));
        facade.registerAppraiser(address(appraiser2));
        vm.prank(appraiser1);
        facade.call_setAppraiserPrice(0, 0, 1000);
        vm.prank(appraiser2);
        facade.call_setAppraiserPrice(0, 0, 3000);
        assertEq(facade.getAppraisalCount(0, 0), 2);
        assertEq(facade.getEpochPrice(0, 0), 2000);
        assertEq(facade.getRewardShare(appraiser1, 0, 0), 5e17);
        assertEq(facade.getRewardShare(appraiser2, 0, 0), 5e17);
    }

    function test_shares2() public {
        address a1 = makeAddr("appraiser1");
        address a2 = makeAddr("appraiser2");
        address a3 = makeAddr("appraiser3");
        facade.setOraclePrice(0, 0, 2987);
        facade.registerAppraiser(address(a1));
        facade.registerAppraiser(address(a2));
        facade.registerAppraiser(address(a3));
        vm.prank(a1);
        facade.call_setAppraiserPrice(0, 0, 1000);
        vm.prank(a2);
        facade.call_setAppraiserPrice(0, 0, 1100);
        vm.prank(a3);
        facade.call_setAppraiserPrice(0, 0, 5000);
        assertEq(facade.getAppraisalCount(0, 0), 3);
        assertEq(facade.getEpochPrice(0, 0), 2800);
        assertEq(facade.getRewardShare(a1, 0, 0), 315789473684210526);
        assertEq(facade.getRewardShare(a2, 0, 0), 298245614035087719);
        assertEq(facade.getRewardShare(a3, 0, 0), 385964912280701754);
    }

    function test_mocked_functions() public {
        facade.setupMockPool(0, 2, block.timestamp + 1 days);
        // data for tokenId=0, price = 1034
        bytes memory data =
            hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040a";
        facade.call_fulfillRequest("", data, "");
        assertEq(facade.getEpochPrice(0, 2), 1034);
    }
}
