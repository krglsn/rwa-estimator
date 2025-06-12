// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1155Core} from "./ERC1155Core.sol";
import {TokenPriceDetails} from "./TokenPriceDetails.sol";

contract RealEstateToken is ERC1155Core, TokenPriceDetails {

    constructor(string memory uri_) ERC1155Core(uri_) {
    }
}