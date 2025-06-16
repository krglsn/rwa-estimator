// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Roles} from "./Roles.sol";
import {Pool} from "./Pool.sol";

contract TokenPriceDetails is Roles {

    error AppraiserNotAllowed(address);
    error PoolNotSet();
    error AppraisalLockTill(uint256);
    error AppraisalAlreadySet();

    uint256 public constant APPRAISAL_LOCK_TIME = 30;

    Pool i_pool;

    struct EpochPrice {
        uint256 oracle;
        uint256 appraisal;
        uint80 count;
    }

    mapping(address => bool) private s_isAppraiser;
    address[] public s_appraisers;
    mapping(uint256 tokenId => mapping(uint256 epochId => EpochPrice)) internal s_tokenEpochData;
    mapping(address => mapping(uint256 tokenid => mapping(uint256 epochId => uint256 price))) internal s_appraisals;


    modifier onlyAppraiser() {
        if (!s_isAppraiser[msg.sender]) {
            revert AppraiserNotAllowed(msg.sender);
        }
        _;
    }

    function registerAppraiser(address appraiser) public onlyIssuerOrItself {
        s_isAppraiser[appraiser] = true;
        s_appraisers.push(appraiser);
    }

    function removeAppraiser(address appraiser) public onlyIssuerOrItself {
        // Not remove appraiser from s_appraisers because it may be have old appraisals.
        s_isAppraiser[appraiser] = false;
//        for (uint256 i = 0; i < s_appraisers.length; i++) {
//            if (s_appraisers[i] == appraiser) {
//                s_appraisers[i] = s_appraisers[s_appraisers.length - 1];
//                s_appraisers.pop();
//                break;
//            }
//        }
    }

    function _getAverageAppraisal(uint256 tokenId, uint256 epochId) internal view returns (uint256 avg) {
    uint256 total = 0;
    uint256 count = 0;
    for (uint256 i = 0; i < s_appraisers.length; i++) {
        address appraiser = s_appraisers[i];
        uint256 price = s_appraisals[appraiser][tokenId][epochId];
        if (price > 0) {
            total += price;
            count++;
        }
    }
    if (count == 0) return 0;
    return total / count;
}

    function getEpochPrice(uint256 tokenId, uint256 epochId) public view returns (uint256 oracle, uint256 appraisal) {
        uint256 oracle_ = s_tokenEpochData[tokenId][epochId].oracle;
        uint256 appraisal_ = s_tokenEpochData[tokenId][epochId].appraisal;
        return (oracle_, appraisal_);
    }



    function setAppraiserPrice(uint256 tokenId, uint256 epochId, uint256 appraisal) external onlyAppraiser {
        if (address(i_pool) == address(0)) {
            revert PoolNotSet();
        }
        (uint256 num, uint256 end) = i_pool.getEpoch();
        if (block.timestamp >= end - APPRAISAL_LOCK_TIME) {
            revert AppraisalLockTill(end);
        }
        if (s_appraisals[msg.sender][tokenId][epochId] != 0) {
            revert AppraisalAlreadySet();
        }
        _setAppraiserPrice(tokenId, epochId, appraisal);
    }

    function _setAppraiserPrice(uint256 tokenId, uint256 epochId, uint256 appraisal) internal onlyAppraiser {
        s_appraisals[msg.sender][tokenId][epochId] = appraisal;
//        uint80 prevCount = s_tokenEpochData[tokenId][epochId].count;
//        uint256 prevCumPrice = s_tokenEpochData[tokenId][epochId].appraisal * prevCount;
//        uint256 newPrice = (prevCumPrice + appraisal) / (prevCount + 1);
//        s_tokenEpochData[tokenId][epochId].appraisal = newPrice;
//        s_tokenEpochData[tokenId][epochId].count++;
    }

    function setOraclePrice(uint256 tokenId, uint256 epochId, uint256 value) external {
        s_tokenEpochData[tokenId][epochId].oracle = value;
    }

    function setPool(address pool) external onlyIssuerOrItself {
        i_pool = Pool(pool);
    }

}
