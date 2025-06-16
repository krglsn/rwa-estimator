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

    // Optional mapping for token URIs
    mapping(uint256 tokenId => string) private _tokenURIs;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    constructor(string memory uri_) ERC1155(uri_) {}

    function mint(address _to, uint256 _id, uint256 _amount, bytes memory _data, string memory _tokenUri)
        public
        onlyIssuerOrItself
    {
        _mint(_to, _id, _amount, _data);
        _tokenURIs[_id] = _tokenUri;
    }

    function mintBatch(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data,
        string[] memory _tokenUris
    ) public onlyIssuerOrItself {
        _mintBatch(_to, _ids, _amounts, _data);
        for (uint256 i = 0; i < _ids.length; ++i) {
            _tokenURIs[_ids[i]] = _tokenUris[i];
        }
    }

    function burn(address account, uint256 id, uint256 amount) public onlyIssuerOrItself {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        _burn(account, id, amount);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];

        return bytes(tokenURI).length > 0 ? tokenURI : super.uri(tokenId);
    }

    function _setURI(uint256 tokenId, string memory tokenURI) internal {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }
}