// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Roles} from "./Roles.sol";
import {Pool} from "./Pool.sol";
import {console} from "../lib/forge-std/src/console.sol";

contract TokenPriceDetails is Roles {

    error AppraiserNotAllowed(address);
    error PoolNotSet();
    error AppraisalLockTill(uint256);
    error AppraisalAlreadySet();

    uint256 public constant APPRAISAL_LOCK_TIME = 30;
    uint256 public constant ORACLE_WEIGHT = 70;
    uint256 public constant APPRAISAL_WEIGHT = 30;

    Pool private i_pool;

    struct EpochPrice {
        uint256 oracle;
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

    function getAppraisalCount(uint256 tokenId, uint256 epochId) public view returns (uint256 count) {
        uint256 total = 0;
        for (uint256 i = 0; i < s_appraisers.length; i++) {
            address appraiser = s_appraisers[i];
            uint256 price = s_appraisals[appraiser][tokenId][epochId];
            if (price > 0) {
                total += price;
                count++;
            }
        }
        return count;
    }

    function getEpochPrice(uint256 tokenId, uint256 epochId) public view returns (uint256 price) {
        // Get average weighted price of oracle and apprasal
        uint256 oracle = s_tokenEpochData[tokenId][epochId].oracle;
        uint256 appraisal = _getAverageAppraisal(tokenId, epochId);
        if (appraisal == 0) {
            price = oracle;
        } else {
            price = (ORACLE_WEIGHT * oracle + APPRAISAL_WEIGHT * appraisal) / 100;
        }
    }

    function getRewardShare(address appraiser, uint256 tokenId, uint256 epochId) external returns (uint256) {
        //Get reward share at specific epoch, normalised to 1e18
        uint256 appraisersCount = getAppraisalCount(tokenId, epochId);
        if (appraisersCount == 0) {
            return 0;
        }
        uint256 refPrice = getEpochPrice(tokenId, epochId);
        uint256 allAppraisers = s_appraisers.length;
        uint256 totalAccuracy = 0;
        uint256 totalWeight = 0;
        uint256 aWeight = 0;

        for (uint256 i = 0; i < s_appraisers.length; i++) {
            address a = s_appraisers[i];
            uint256 appraisal = s_appraisals[a][tokenId][epochId];
            if (appraisal > 0) {
                uint256 diff = appraisal > refPrice ? (appraisal - refPrice) : (refPrice - appraisal);
                uint256 weight = diff * 1e18 / refPrice;
                totalWeight += weight;
                if (a == appraiser) {
                    aWeight += weight;
                }
            }
        }
        if (totalWeight == 0) {
            return 0;
        }
        return aWeight * 1e18 / totalWeight;
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
    }

    function setOraclePrice(uint256 tokenId, uint256 epochId, uint256 value) public onlyIssuerOrItself {
        s_tokenEpochData[tokenId][epochId].oracle = value;
    }

    function setPool(address pool) external onlyIssuerOrItself {
        i_pool = Pool(pool);
    }

}
