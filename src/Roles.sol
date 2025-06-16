pragma solidity 0.8.24;

import {OwnerIsCreator} from "lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";

contract Roles is OwnerIsCreator {

    address internal s_issuer;

    event SetIssuer(address indexed issuer);

    error ERC1155Core_CallerIsNotIssuerOrItself(address msgSender);

    modifier onlyIssuerOrItself() {
        if (msg.sender != address(this) && msg.sender != s_issuer) {
            revert ERC1155Core_CallerIsNotIssuerOrItself(msg.sender);
        }
        _;
    }

    function setIssuer(address _issuer) external onlyOwner {
        s_issuer = _issuer;
        emit SetIssuer(_issuer);
    }
}