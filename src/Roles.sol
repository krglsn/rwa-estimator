// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {OwnerIsCreator} from "lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract Roles is OwnerIsCreator {
    address internal s_issuer;

    event SetIssuer(address indexed issuer);

    error ERC1155Core_CallerIsNotIssuerOrItself(address msgSender);
    error ERC1155Core_CallerIsNotIssuerOrOwner(address msgSender);

    modifier onlyIssuerOrItself() {
        if (msg.sender != address(this) && msg.sender != s_issuer) {
            revert ERC1155Core_CallerIsNotIssuerOrItself(msg.sender);
        }
        _;
    }

    modifier onlyIssuerOrOwner() {
        if (msg.sender != this.owner() && msg.sender != s_issuer) {
            revert ERC1155Core_CallerIsNotIssuerOrOwner(msg.sender);
        }
        _;
    }

    function setIssuer(address _issuer) external onlyOwner {
        s_issuer = _issuer;
        emit SetIssuer(_issuer);
    }
}
