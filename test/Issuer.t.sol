pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Issuer} from "../src/Issuer.sol";
import {RealEstateToken} from "../src/RealEstateToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";

contract IssuerTest is Test {
    Issuer public issuer;
    RealEstateToken public token;
    Pool public pool;

    function setUp() public {
        token = new RealEstateToken("t.t");
        console.log("Token %s", address(token));
        pool = new Pool(address(token));
        console.log("Pool %s", address(pool));
        issuer = new Issuer(address(token));
        console.log("Issuer %s", address(issuer));
        token.setIssuer(address(issuer));
        pool = new Pool(address(token));
        pool.setIssuer(address(issuer));
    }

    function test_Issue() public {
        address target = 0x50e646d516fED1371aE363C7d6dc7cA951e82604;
        assertFalse(token.exists(0));
        issuer.issue("test.url", target, 100, address(pool), 1, 1, 1);
        assertTrue(token.exists(0));
        uint256 balance = token.balanceOf(target, 0);
        assertEq(balance, 100);
        assertFalse(token.exists(1));
        uint256 id = issuer.issue("test2.url", target, 200, address(pool), 1, 1, 1);
        assertEq(id, 1);
        assertTrue(token.exists(1));
        balance = token.balanceOf(target, 1);
        assertEq(balance, 200);
        assertEq(200, token.totalSupply(1));
    }

    function test_poolAssignment() public {
        address target = 0x50e646d516fED1371aE363C7d6dc7cA951e82604;
        assertFalse(token.exists(0));
        uint256 tokenId = issuer.issue("another_test", target, 111, address(pool), 11, 22, 33);
        Pool.UsagePlan memory plan = pool.getPlan();
        assertEq(plan.rentAmount, 11);
        assertEq(plan.epochDuration, 22);
        assertEq(plan.programEnd, 33);
    }
}