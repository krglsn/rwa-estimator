// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RealEstateToken} from "./RealEstateToken.sol";
import {OwnerIsCreator} from "lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {PriceDetails} from "./PriceDetails.sol";

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
    uint256 private s_currentId;
    mapping(bytes32 requestId => FractionalizedNft) internal s_issuedTokens;

    constructor(address realEstateToken) {
        s_currentId = 0;
        i_realEstateToken = RealEstateToken(realEstateToken);
    }

    function issue(string calldata uri, address to, uint256 amount) external onlyOwner returns (uint256 tokenId)
    {
        i_realEstateToken.mint(to, s_currentId, amount, new bytes(0), uri);
        s_currentId++;
        return s_currentId - 1;
    }

}