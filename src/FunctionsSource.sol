// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
abstract contract FunctionsSource {

    string public getPrice =
        "const { ethers } = await import('npm:ethers@6.10.0');"
        "const tokenId = args[0];"
        "const epochId = 0;"
        "const abiCoder = ethers.AbiCoder.defaultAbiCoder();"
        "const encoded = abiCoder.encode([`uint256`, `uint256`, `uint256`], [tokenId, epochId, 100]);"
        "console.log(encoded);"
        "return ethers.getBytes(encoded);";
}