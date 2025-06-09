// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RealEstateToken} from "./RealEstateToken.sol";
import {OwnerIsCreator} from "lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract Issuer is OwnerIsCreator {

    error LatestIssueInProgress();

    struct FractionalizedNft {
        address to;
        uint256 amount;
    }

    RealEstateToken internal immutable i_realEstateToken;

    bytes32 internal s_lastRequestId;
    uint256 private s_nextTokenId;

    mapping(bytes32 requestId => FractionalizedNft) internal s_issuesInProgress;

    constructor(address realEstateToken) {
        i_realEstateToken = RealEstateToken(realEstateToken);
    }

    function issue(address to, uint256 amount)
        external
        onlyOwner
        returns (bytes32 requestId)
    {
        if (s_lastRequestId != bytes32(0)) revert LatestIssueInProgress();

        s_issuesInProgress[requestId] = FractionalizedNft(to, amount);
        i_realEstateToken.mint(to, uint256(requestId), amount, new bytes(0), "test.url");

        s_lastRequestId = requestId;
    }

    function cancelPendingRequest() external onlyOwner {
        s_lastRequestId = bytes32(0);
    }

}