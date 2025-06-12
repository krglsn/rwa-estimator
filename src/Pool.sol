// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {RealEstateToken} from "./RealEstateToken.sol";
import {OwnerIsCreator} from "lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";


contract Pool is OwnerIsCreator {

    error TokenIdNotFound();
    error NotIssuerOrItself(address);

    event SetIssuer(address indexed issuer);

    struct UsagePlan {
        uint256 rentAmount;
        uint256 epochDuration;
        uint256 programEnd;
    }

    address s_issuer;
    uint256 private tokenId;
    UsagePlan plan;

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

    function assign(uint256 tokenId_, uint256 rentAmount_, uint256 epochDuration_, uint256 programEnd_) external onlyIssuerOrItself {
        if (!i_realEstateToken.exists(tokenId_)) {
            revert TokenIdNotFound();
        }
        tokenId = tokenId_;
        plan = UsagePlan({
            rentAmount: rentAmount_,
            epochDuration: epochDuration_,
            programEnd: programEnd_
        });
    }

    function getPlan() external view returns (UsagePlan memory) {
        return plan;
    }
}
