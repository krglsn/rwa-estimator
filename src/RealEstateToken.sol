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

    /**
     * @notice Burn tokens
     * @param account Address of the token holder
     * @param id ERC1155 Token identifier
     * @param amount Amount of Token[id] to burn
     */
    function burn(address account, uint256 id, uint256 amount) public {
        if (msg.sender != s_issuer && msg.sender != s_pool[id]) {
            revert NotAssetOwner(msg.sender, s_pool[id]);
        }
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }
        _burn(account, id, amount);
    }
}
