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

    mapping(address => bool) private s_appraisers;

    struct EpochPrice {
        uint256 oracle;
        uint256 appraisal;
        uint80 count;
    }

    mapping(uint256 tokenId => mapping(uint256 epochId => EpochPrice)) internal s_tokenEpochData;

    modifier onlyAppraiser() {
        if (!s_appraisers[msg.sender]) {
            revert AppraiserNotAllowed(msg.sender);
        }
        _;
    }

    function registerAppraiser(address appraiser) public {
        s_appraisers[appraiser] = true;
    }

    function removeAppraiser(address appraiser) public {
        s_appraisers[appraiser] = false;
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
        if (s_tokenEpochData[tokenId][epochId].appraisal != 0) {
            revert AppraisalAlreadySet();
        }
        _setAppraiserPrice(tokenId, epochId, appraisal);
    }

    function _setAppraiserPrice(uint256 tokenId, uint256 epochId, uint256 appraisal) internal onlyAppraiser {
        uint80 prevCount = s_tokenEpochData[tokenId][epochId].count;
        uint256 prevCumPrice = s_tokenEpochData[tokenId][epochId].appraisal * prevCount;
        uint256 newPrice = (prevCumPrice + appraisal) / (prevCount + 1);
        s_tokenEpochData[tokenId][epochId].appraisal = newPrice;
        s_tokenEpochData[tokenId][epochId].count++;
    }

    function setOraclePrice(uint256 tokenId, uint256 epochId, uint256 value) external {
        s_tokenEpochData[tokenId][epochId].oracle = value;
    }

    function setPool(address pool) external onlyIssuerOrItself {
        i_pool = Pool(pool);
    }

}
