pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Issuer} from "../src/Issuer.sol";
import {RealEstateToken} from "../src/RealEstateToken.sol";
import {Test, console} from "forge-std/Test.sol";

contract IssuerTest is Test {
    Issuer public issuer;
    RealEstateToken public token;

    function setUp() public {
        token = new RealEstateToken("t.t");
        console.log("Token %s", address(token));
        issuer = new Issuer(address(token));
        console.log("Issuer %s", address(issuer));
        token.setIssuer(address(issuer));
    }

    function test_Issue() public {
        address target = 0x50e646d516fED1371aE363C7d6dc7cA951e82604;
        assertFalse(token.exists(0));
        issuer.issue("test.url", target, 100);
        assertTrue(token.exists(0));
        uint256 balance = token.balanceOf(target, 0);
        assertEq(balance, 100);
        assertFalse(token.exists(1));
        uint256 id = issuer.issue("test2.url", target, 200);
        assertEq(id, 1);
        assertTrue(token.exists(1));
        balance = token.balanceOf(target, 1);
        assertEq(balance, 200);
        assertEq(200, token.totalSupply(1));

    }

    function test_priceDetails() public {
        address target = 0x50e646d516fED1371aE363C7d6dc7cA951e82604;
        assertFalse(token.exists(0));
        issuer.issue("another_test", target, 100);
        assertTrue(token.exists(0));
        token.setPrice(0, 150);
        token.setPrice(0, 300);
        assertEq(token.getPrice(0).price, 300);
    }
}