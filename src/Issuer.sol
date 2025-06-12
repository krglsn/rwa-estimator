// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RealEstateToken} from "./RealEstateToken.sol";
import {OwnerIsCreator} from "lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {TokenPriceDetails} from "./TokenPriceDetails.sol";
import {Pool} from "./Pool.sol";


/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract Issuer is OwnerIsCreator {

    struct FractionalizedNft {
        address to;
        uint256 amount;
    }

    RealEstateToken internal immutable i_realEstateToken;
    Pool internal immutable i_pool;
    uint256 private s_currentId;
    mapping(bytes32 requestId => FractionalizedNft) internal s_issuedTokens;

    constructor(address realEstateToken_, address pool_) {
        s_currentId = 0;
        i_realEstateToken = RealEstateToken(realEstateToken_);
        i_pool = Pool(pool_);
    }

    function issue(string calldata uri, address to, uint256 amount, uint256 rentPlan) external onlyOwner returns (uint256 tokenId)
    {
        i_realEstateToken.mint(to, s_currentId, amount, new bytes(0), uri);
        i_pool.assign(s_currentId, rentPlan);
        s_currentId++;
        return s_currentId - 1;
    }

}