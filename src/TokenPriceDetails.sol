// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {FunctionsClient} from "../lib/chainlink-evm/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "../lib/chainlink-evm/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ConfirmedOwnerWithProposal} from
    "../lib/chainlink-evm/contracts/src/v0.8/shared/access/ConfirmedOwnerWithProposal.sol";
import {FunctionsSource} from "./FunctionsSource.sol";
import {Pool} from "./Pool.sol";
import {Roles} from "./Roles.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract TokenPriceDetails is Roles, FunctionsClient, FunctionsSource {
    using FunctionsRequest for FunctionsRequest.Request;

    error AppraiserNotAllowed(address);
    error PoolNotSet();
    error AppraisalLockTill(uint256);
    error AppraisalAlreadySet();
    error OnlyAutomationForwarderOrOwnerCanCall();
    error PastAppraisalForbidden();
    error AppraiserAlreadyRegistered();
    error NotAssetOwner(address sender, address pool);

    // Seconds in the end of epoch to forbid appraisals
    uint256 public constant APPRAISAL_LOCK_TIME = 30;

    // Oracle price weight in resulting price
    uint256 public constant ORACLE_WEIGHT = 70;

    // Average appraisal weigth in resulting price
    uint256 public constant APPRAISAL_WEIGHT = 30;

    // Owners for tokenId assets
    mapping(uint256 tokenId => address) private _assetOwners;

    // Chainlink functions forwarder
    address internal s_automationForwarderAddress;

    struct EpochPrice {
        uint256 oracle;
        uint80 count;
    }

    mapping(uint256 => address) internal s_pool;
    mapping(address => bool) private s_isAppraiser;
    address[] public s_appraisers;
    mapping(uint256 tokenId => mapping(uint256 epochId => EpochPrice)) internal s_tokenEpochData;
    mapping(address => mapping(uint256 tokenId => mapping(uint256 epochId => uint256 price))) internal s_appraisals;

    modifier onlyAppraiser() {
        if (!s_isAppraiser[msg.sender]) {
            revert AppraiserNotAllowed(msg.sender);
        }
        _;
    }

    modifier onlyAutomationForwarderOrOwner() {
        if (msg.sender != s_automationForwarderAddress && msg.sender != owner()) {
            revert OnlyAutomationForwarderOrOwnerCanCall();
        }
        _;
    }

    constructor(address functionsRouterAddress) FunctionsClient(functionsRouterAddress) {}

    function setAutomationForwarder(address automationForwarderAddress) external onlyOwner {
        s_automationForwarderAddress = automationForwarderAddress;
    }

    /**
     * @notice Register address as Appraiser, so it can send appraisals.
     */
    function registerAppraiser(address appraiser) public onlyOwner {
        for (uint256 i = 0; i < s_appraisers.length; i++) {
            if (s_appraisers[i] == appraiser) {
                revert AppraiserAlreadyRegistered();
            }
        }
        s_isAppraiser[appraiser] = true;
        s_appraisers.push(appraiser);
    }

    /**
     * @notice Unregister Appraiser.
     */
    function removeAppraiser(address appraiser) public onlyOwner {
        // Not remove appraiser from s_appraisers because it may be have old appraisals.
        s_isAppraiser[appraiser] = false;
    }

    /**
     * @notice Check if address is allowd Appraiser.
     */
    function isAppraiser(address appraiser) external view returns (bool) {
        return s_isAppraiser[appraiser];
    }

    /**
     * @notice Get averaged appraisal.
     */
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

    /**
     * @notice Get number of appraisals for tokenId and epochId.
     */
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

    /**
     * @notice Get price for tokenId and epochId, weighted by oracle and all available appraisals.
     */
    function getEpochPrice(uint256 tokenId, uint256 epochId) public view returns (uint256 price) {
        // Get average weighted price of oracle and apprasal
        uint256 oracle = s_tokenEpochData[tokenId][epochId].oracle;
        uint256 appraisal = _getAverageAppraisal(tokenId, epochId);
        if (appraisal == 0) {
            price = oracle;
        } else if (oracle == 0) {
            price = appraisal;
        } else {
            price = (ORACLE_WEIGHT * oracle + APPRAISAL_WEIGHT * appraisal) / 100;
        }
    }

    /**
     * @notice Get share of rewards for specified Appraiser by specified epoch.
     */
    function getRewardShare(address appraiser, uint256 tokenId, uint256 epochId) external view returns (uint256) {
        //Get reward share at specific epoch, normalised to 1e18
        uint256 appraisersCount = getAppraisalCount(tokenId, epochId);
        if (appraisersCount == 0) {
            return 0;
        }
        uint256 refPrice = getEpochPrice(tokenId, epochId);
        uint256 totalWeight = 0;
        uint256 aWeight = 0;

        for (uint256 i = 0; i < s_appraisers.length; i++) {
            address a = s_appraisers[i];
            uint256 appraisal = s_appraisals[a][tokenId][epochId];
            if (appraisal > 0) {
                uint256 diff = appraisal > refPrice ? (appraisal - refPrice) : (refPrice - appraisal);
                if (diff == 0) {
                    diff = 1;
                }
                uint256 weight = refPrice * 1e18 / diff;
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

    /**
     * @notice Set price by Appraiser.
     */
    function setAppraiserPrice(uint256 tokenId, uint256 epochId, uint256 appraisal) external onlyAppraiser {
        if (s_pool[tokenId] == address(0)) {
            revert PoolNotSet();
        }
        Pool pool = Pool(s_pool[tokenId]);
        (uint256 currentEpoch, uint256 end) = pool.getEpoch();
        if (epochId < currentEpoch) {
            revert PastAppraisalForbidden();
        }
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

    /**
     * @notice Test function to be able to override Oracle price that normally comes from Chainlink functions.
     */
    function setOraclePrice(uint256 tokenId, uint256 epochId, uint256 value) public onlyIssuerOrOwner {
        s_tokenEpochData[tokenId][epochId].oracle = value;
    }

    /**
     * @notice Get oracle price for tokenId and epochId, not considering appraisals.
     */
    function getOraclePrice(uint256 tokenId, uint256 epochId) external view returns (uint256 oraclePrice) {
        oraclePrice = s_tokenEpochData[tokenId][epochId].oracle;
    }

    /**
     * @notice Associate Pool with tokenId.
     * @dev Pool is required to get epoch and timing information.
     */
    function setPool(uint256 tokenId, address pool) public onlyIssuerOrOwner {
        s_pool[tokenId] = pool;
    }

    /**
     * @notice Get associated pool address.
     */
    function getPool(uint256 tokenId) external view returns (address pool) {
        pool = s_pool[tokenId];
    }

    /**
     * @notice Update oracle price by Chainlink Functions forwarder.
     */
    function updatePriceDetails(string memory tokenId, uint64 subscriptionId, uint32 gasLimit, bytes32 donID)
        external
        onlyAutomationForwarderOrOwner
        returns (bytes32 requestId)
    {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(this.getPrice());

        string[] memory args = new string[](1);
        args[0] = tokenId;

        req.setArgs(args);

        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donID);
    }

    /**
     * @notice Update oracle price by Chainlink Functions forwarder.
     */
    function fulfillRequest(bytes32, /*requestId*/ bytes memory response, bytes memory err) internal override {
        if (err.length != 0) {
            revert(string(err));
        }
        (uint256 tokenId, uint256 oraclePrice) = abi.decode(response, (uint256, uint256));
        if (s_pool[tokenId] == address(0)) {
            revert PoolNotSet();
        }
        Pool pool = Pool(s_pool[tokenId]);
        (uint256 epochId,) = pool.getEpoch();
        s_tokenEpochData[tokenId][epochId].oracle = oraclePrice;
    }

    /**
     * @notice Set assetOwner for specific tokenId
     */
    function setAssetOwner(uint256 tokenId, address admin) public {
        if (msg.sender != s_issuer && msg.sender != s_pool[tokenId]) {
            revert NotAssetOwner(msg.sender, s_pool[tokenId]);
        }
        _assetOwners[tokenId] = admin;
    }

    /**
     * @notice Check if specified address is asset owner
     */
    function isAssetOwner(uint256 tokenId, address admin) public view returns (bool) {
        return _assetOwners[tokenId] == admin;
    }
}
