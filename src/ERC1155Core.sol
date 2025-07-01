// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1155Supply} from "lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Roles} from "./Roles.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract ERC1155Core is ERC1155Supply, Roles {
    error AlreadyMinted();

    // Optional mapping for token URIs
    mapping(uint256 tokenId => string) private _tokenURIs;

    // Used as the URI for all token types
    constructor(string memory uri_) ERC1155(uri_) {}

    /**
     * @notice Mints new tokenId in ERC1155 to user, assigns URI
     * @param _to Address of the token recipient
     * @param _id ERC1155 Token identifier
     * @param _amount Amount of Token[_id] to mint
     * @param _data Additional data to pass to the recipient via onERC1155Received callback
     * @param _tokenUri IPFS link to token metadata
     */
    function mint(address _to, uint256 _id, uint256 _amount, bytes memory _data, string memory _tokenUri)
        public
        onlyIssuerOrItself
    {
        if (totalSupply(_id) > 0) {
            revert AlreadyMinted();
        }
        _mint(_to, _id, _amount, _data);
        _tokenURIs[_id] = _tokenUri;
    }

    /**
     * @notice Burn tokens
     * @param account Address of the token holder
     * @param id ERC1155 Token identifier
     * @param amount Amount of Token[id] to burn
     */
    function burn(address account, uint256 id, uint256 amount) public onlyIssuerOrItself {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }
        _burn(account, id, amount);
    }

    /**
     * @notice Get URI assigned to token.
     * @param tokenId ERC1155 Token identifier
     * @return URI string for the token
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];
        return bytes(tokenURI).length > 0 ? tokenURI : super.uri(tokenId);
    }

    /**
     * @notice Set URI for a specific token
     * @param tokenId ERC1155 Token identifier
     * @param tokenURI URI to set for the token
     */
    function _setURI(uint256 tokenId, string memory tokenURI) internal {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }
}
