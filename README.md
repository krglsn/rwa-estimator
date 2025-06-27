# Decentralized RWA Estimator

## License
This project is licensed under the [MIT License](LICENSE).

## Overview

A decentralized protocol for Real World Asset (RWA) valuation using independent appraisers and on-chain aggregation logic.

The set of smart contracts supports multiple valuation epochs, fair reward distribution, and integration with [Chainlink Functions](https://docs.chain.link/chainlink-functions) for oracle pricing.

## Architecture
Project is based on ERC1155 token, extended with TokenPriceDetails contract. See `src/RealEstateToken.sol`, `TokenPriceDetails.sol` and `ERC1155Core.sol` contracts.  

Pool contract (`src/Pool.sol`) is associated with certain `TokenId` and manages epoch calclulations for:
- Deposit and Withdraw Tokenized Asset shares (via Token)
- Swap logic (Native <-> Token) in accordance with current prices
- Rent payments and safety margin
- Rewards distribution to Depositors and Appraisers

TokenPriceDetails (`src/TokenPriceDetails`) manages price aggregation from:
- oracle price set by Chainlink Functions
- averaging prices set by Appraisers per token and epoch

Issuer contract (`Issuer.sol`) is main entry point for deployment and handles initial initalisation of Token and Pool contracts.

Functions contract contains simple functions to provide oracle pricing via [Chainlink Functions](https://docs.chain.link/chainlink-functions) 

## Build and test
Make sure you have [Foundry tools](https://getfoundry.sh/) installed.
Tests cover most of the contracts functionality and could be helpfull in reviewing typical flows and use cases.
```shell
forge test -vvv
```

## Deploy

### Local forked environment
1. Prepare chain fork with Anvil:
```shell
 anvil --block-time 2  --rpc-url https://sepolia.gateway.tenderly.co
```
2. Deploy token and a couple of pools (see the script for more details):
```shell
forge script script/RealEstate.s.sol:DeployAll --rpc-url local --broadcast 
```
3. Optional: topup accounts with some funds:
```shell
cast send --from 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 <your address> --value "6 ether" --unlocked;

```
