// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

/**
 * @title RealEstateToken
 * @dev Contract combines ERC1155 assets tokenization and token price based on oracle + decentralised appraisals.
 */
import {ERC1155Core} from "./ERC1155Core.sol";
import {TokenPriceDetails} from "./TokenPriceDetails.sol";

contract RealEstateToken is ERC1155Core, TokenPriceDetails {
    constructor(string memory uri_, address functionsRouterAddress)
        ERC1155Core(uri_)
        TokenPriceDetails(functionsRouterAddress)
    {}
}
