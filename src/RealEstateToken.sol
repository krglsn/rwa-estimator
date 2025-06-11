// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1155Core} from "./ERC1155Core.sol";
import {PriceDetails} from "./PriceDetails.sol";

contract RealEstateToken is ERC1155Core, PriceDetails {

    constructor(string memory uri_) ERC1155Core(uri_) {
    }
}