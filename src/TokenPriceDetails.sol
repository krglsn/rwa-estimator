// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract TokenPriceDetails {

    error AppraiserNotAllowed();

    mapping(address => bool) private s_appraisers;

    struct EpochPrice {
        uint256 oracle;
        uint256 appraisal;
        uint80 count;
    }

    mapping(uint256 tokenId => mapping(uint256 epochId => EpochPrice)) internal s_tokenEpochData;

    modifier onlyAppraiser() {
        if (!s_appraisers[msg.sender]) {
            revert AppraiserNotAllowed();
        }
        _;
    }

    function registerAppraiser(address appraiser) external {
        s_appraisers[appraiser] = true;
    }

    function removeAppraiser(address appraiser) external {
        s_appraisers[appraiser] = false;
    }

    function getEpochPrice(uint256 tokenId, uint256 epochId) external view returns (uint256 oracle, uint256 appraisal) {
        uint256 oracle_ = s_tokenEpochData[tokenId][epochId].oracle;
        uint256 appraisal_ = s_tokenEpochData[tokenId][epochId].appraisal;
        return (oracle_, appraisal_);
    }

    function setAppraiserPrice(uint256 tokenId, uint256 epochId, uint256 appraisal) external onlyAppraiser {
        uint80 prevCount = s_tokenEpochData[tokenId][epochId].count;
        uint256 prevCumPrice = s_tokenEpochData[tokenId][epochId].appraisal * prevCount;
        uint256 newPrice = (prevCumPrice + appraisal) / (prevCount + 1);
        s_tokenEpochData[tokenId][epochId].appraisal = newPrice;
        s_tokenEpochData[tokenId][epochId].count++;
    }

    function setOraclePrice(uint256 tokenId, uint256 epochId, uint256 value) external {
        s_tokenEpochData[tokenId][epochId].oracle = value;
    }
}
