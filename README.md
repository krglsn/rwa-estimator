# Decentralized RWA Estimator

## License

This project is licensed under the [MIT License](LICENSE).

## Overview

A decentralized protocol for Real World Asset (RWA) valuation using independent appraisers and on-chain aggregation logic.

The smart contracts support:
- Multiple valuation epochs
- Fair reward distribution
- Integration with [Chainlink Functions](https://docs.chain.link/chainlink-functions) for oracle-based RWA pricing

## Architecture

The protocol is built on an ERC-1155 token, extended with pricing and pool logic.

### Core Contracts

- `RealEstateToken.sol`, `TokenPriceDetails.sol`, `ERC1155Core.sol`  
  Extend ERC-1155 to support tokenized assets with pricing metadata.

- `Pool.sol`  
  Associated with a specific `tokenId`, manages epoch calculations for:
  - Deposits and withdrawals of tokenized asset shares
  - Native <-> Token swap logic based on current price
  - Rent payments and safety margins
  - Reward distribution to depositors and appraisers

- `TokenPriceDetails.sol`  
  Aggregates price data from:
  - Oracle (via Chainlink Functions)
  - Appraisers (average of submitted prices per token and epoch)

- `Issuer.sol`  
  The main entry point. Deploys and initializes the token and pool contracts.

- `Functions.sol`  
  Provides a basic Chainlink Functions integration for external price fetches.

## Current limitations and future improvements
- **Mocked reference price**  
  The reference price is currently hardcoded within the Chainlink Function. In future iterations, this can be replaced with real-time data from trusted external APIs.

- **No decimal precision handling**  
  Token and price calculations currently do not account for decimals, which may result in inaccurate valuations. This can be addressed by introducing fixed-point math or token-specific decimal support.

- **Native token only**  
  All deposits and payments are made using the network’s native currency. Future improvements include supporting **stablecoins** and **Chainlink Price Feeds** for better stability and usability.

- **Liquidation logic not implemented**  
  The liquidation function is scaffolded but not fully implemented due to time constraints. Completing this feature is a top priority for ensuring trustless enforcement of obligations.

- **Limited liquidation conditions**  
  At the moment, liquidation is only triggered by delayed rent payments. This logic could be extended to also consider the owner’s safety deposit balance and other risk indicators.

- **Simplified ownership model**  
  The current design assumes a single token owner. A more flexible ownership structure — allowing multiple owners or delegated roles — would make the system more robust.

- **No withdrawal queue or prioritization**  
  Withdrawals are currently processed without order or delay logic. A prioritization queue would improve fairness and predictability for users.

- **Lack of UI feedback for reward claims**  
  Users are not clearly informed when reward claims are restricted or unavailable. Future UI updates should provide transparent status and timing information for pending rewards.


## Build and Test

Make sure you have [Foundry](https://getfoundry.sh/) installed.

Run tests (covering most flows and contract logic):

```bash
forge test -vvv
```

## Deploy

### Local Fork (Anvil)

1. Start Anvil with a Sepolia fork:

   ```bash
   anvil --block-time 2 --rpc-url https://sepolia.gateway.tenderly.co
   ```

2. In a new terminal, deploy token and pools:

   ```bash
   forge script script/RealEstate.s.sol:DeployAll --rpc-url local --broadcast
   ```

3. Optionally, top up local accounts:

   ```bash
   cast send --from 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 <your-address> --value "6 ether" --unlocked
   ```

4. Interact with contracts or connect the Web UI using:

   ```
   RPC: http://localhost:8545  
   WebSocket: ws://localhost:8545
   ```

## Contributions

Contributions, issues, and suggestions are welcome!
