// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
abstract contract FunctionsSource {
    /**
     * @notice Chainlink Function to get current price from offchain oracle.
     * @dev For sake of simplicity it returns just hardcoded function of tokenId with some randomization.
     * @dev In real application it may trigger RWA API or another offchain oracle.
     */
    string public getPrice = "const { ethers } = await import('npm:ethers@6.10.0');" "const tokenId = args[0];"
        "const abiCoder = ethers.AbiCoder.defaultAbiCoder();" "const randomFactor = Math.floor(Math.random() * 50);"
        "const price = 1000 + tokenId * 100 + randomFactor;"
        "const encoded = abiCoder.encode([`uint256`, `uint256`], [tokenId, price]);" "console.log(encoded);"
        "return ethers.getBytes(encoded);";
}
