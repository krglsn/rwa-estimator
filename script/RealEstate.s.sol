// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RealEstateToken.sol";
import {Issuer} from "../src/Issuer.sol";
import "../src/Pool.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        RealEstateToken token = new RealEstateToken(
            "https://ipfs.io/ipfs/bafkreib6kdfdaieuilfuhf6gotitktddynxehnqke5pyqcsz5m2wazss44",
    0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0
        );
        Pool pool = new Pool(address(token));
        Issuer issuer = new Issuer(address(token));
        token.setIssuer(address(issuer));
        vm.stopBroadcast();
    }
}