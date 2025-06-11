// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract PriceDetails {

    struct _PriceDetails {
        uint80 price;
    }

    mapping(uint256 tokenId => _PriceDetails) internal s_priceDetails;

    function setPrice (uint256 tokenId, uint80 price) public {
        s_priceDetails[tokenId] = _PriceDetails(price);
    }

    function getPrice (uint256 tokenId) public view returns (_PriceDetails memory price) {
        return s_priceDetails[tokenId];
    }
}
