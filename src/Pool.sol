// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {RealEstateToken} from "./RealEstateToken.sol";
import {OwnerIsCreator} from "lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";


contract Pool is OwnerIsCreator {

    error TokenIdNotFound();
    error NotIssuerOrItself(address);

    event SetIssuer(address indexed issuer);

    mapping(uint256 tokenId => uint256) internal s_assignedTokens;
    address s_issuer;

    RealEstateToken internal immutable i_realEstateToken;

    modifier onlyIssuerOrItself() {
        if (msg.sender != address(this) && msg.sender != s_issuer) {
            revert NotIssuerOrItself(msg.sender);
        }
        _;
    }

    constructor(address realEstateToken){
        i_realEstateToken = RealEstateToken(realEstateToken);
    }

    function setIssuer(address _issuer) external onlyOwner {
        s_issuer = _issuer;

        emit SetIssuer(_issuer);
    }

    function assign(uint256 tokenId, uint256 rentPlan) external onlyIssuerOrItself {
        if (!i_realEstateToken.exists(tokenId)) {
            revert TokenIdNotFound();
        }
        s_assignedTokens[tokenId] =  rentPlan;
    }

    function getPlan(uint256 tokenId) external view returns (uint256) {
        return s_assignedTokens[tokenId];
    }
}
