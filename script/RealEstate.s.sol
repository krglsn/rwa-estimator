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
            "ifps://bafkreib6kdfdaieuilfuhf6gotitktddynxehnqke5pyqcsz5m2wazss44",
            0xb83E47C2bC239B3bf370bc41e1459A34b41238D0
        );
        //        Pool pool = new Pool(address(token));
        Issuer issuer = new Issuer(address(token));
        token.setIssuer(address(issuer));
        vm.stopBroadcast();
    }
}

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        RealEstateToken token = new RealEstateToken(
            "ipfs://bafkreidyvejmrnko4tsqydcv4pykstiuysfxkjchwm4yfu6td3wglfmiqu",
            0xb83E47C2bC239B3bf370bc41e1459A34b41238D0
        );
        Pool pool = new Pool(address(token));
        Pool pool2 = new Pool(address(token));
        Issuer issuer = new Issuer(address(token));
        token.setIssuer(address(issuer));
        pool.setIssuer(address(issuer));
        pool2.setIssuer(address(issuer));

        issuer.issue(
            "ipfs://bafkreiblchmsdpzcnh2x4p3y7xhsgl2ffxmyozsdun2v6au4qsntbmgdlm",
            address(pool),
            100,
            5e16,
            3600,
            1907577068
        );
        issuer.issue(
            "ipfs://bafkreiayxab2mw5pi4fzpfd7aamypcdqr4adn4li4qxk7fyvwvvkfjloye",
            address(pool2),
            1000,
            8000,
            7200,
            1907577068
        );

        console.log("RealEstateToken at:", address(token));
        console.log("Pool at:", address(pool));
        console.log("Issuer at:", address(issuer));

        vm.stopBroadcast();
    }
}

contract DeployAvalancheFuji is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        RealEstateToken token = new RealEstateToken(
            "ipfs://bafkreidyvejmrnko4tsqydcv4pykstiuysfxkjchwm4yfu6td3wglfmiqu",
            0x9f82a6A0758517FD0AfA463820F586999AF314a0
        );
        Pool pool = new Pool(address(token));
        Pool pool2 = new Pool(address(token));
        Issuer issuer = new Issuer(address(token));
        token.setIssuer(address(issuer));
        pool.setIssuer(address(issuer));
        pool2.setIssuer(address(issuer));

        issuer.issue(
            "ipfs://bafkreiblchmsdpzcnh2x4p3y7xhsgl2ffxmyozsdun2v6au4qsntbmgdlm",
            address(pool),
            100,
            5e16,
            3600,
            1907577068
        );
        issuer.issue(
            "ipfs://bafkreiayxab2mw5pi4fzpfd7aamypcdqr4adn4li4qxk7fyvwvvkfjloye",
            address(pool2),
            1000,
            8000,
            7200,
            1907577068
        );

        console.log("RealEstateToken at:", address(token));
        console.log("Pool at:", address(pool));
        console.log("Issuer at:", address(issuer));
        vm.stopBroadcast();
    }
}
