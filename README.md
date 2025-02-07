# X1Coin & Staking Contracts

## Overview
X1Coin is an **ERC-20 token** designed for the X1 racing ecosystem, featuring a **staking contract** that allows users to stake tokens and earn rewards. The project includes:
- **X1Coin (ERC-20 token)** with **fixed supply and token distribution**.
- **Staking Contract** with **reward tiers and time-based multipliers**.
- **Deployment scripts** using **Foundry**.
- **Comprehensive test suite** ensuring contract correctness and security.

## Features
###  X1Coin (ERC-20 Token)
- **Fixed supply of 1 billion X1Coins**.
- **Token distribution**:
  - **50% Public Sale**.
  - **30% Team & Advisors** (locked for 6 months).
  - **20% Community Development**.
- **Team tokens have a 6-month lock** before they can be transferred.
- **Minting mechanism for staking rewards**.

###  Staking Contract
- **Users can stake X1Coin** and earn rewards.
- **Fixed annual reward rate of 10%**.
- **Bonus reward multipliers**:
  - **90 days → 1.25x rewards**.
  - **180 days → 1.5x rewards**.
  - **365 days → 2x rewards**.
- **Minimum staking period of 30 days**.
- **Unstaking function with reward distribution**.
- **Security**: Uses **ReentrancyGuard** and follows Solidity best practices.

## Deployment
### **Prerequisites**
- **Foundry** (for testing and deployment): [Install Foundry](https://getfoundry.sh/)

### **1️⃣ Setup**
```sh
git clone <repo_url>
cd X1-Racing$
make install
forge build
```

### **2️⃣ Tests**
```sh
forge test
```

### **3️⃣ Set Up Environment Variables**
Create a `.env` file and define:
```sh
PRIVATE_KEY=<your_private_key>
TEAM_WALLET=<team_wallet_address>
COMMUNITY_WALLET=<community_wallet_address>
```

### **4️⃣ Deploy Contracts**
```sh
forge script script/DeployX1Coin.s.sol --fork-url <RPC_URL> --private-key $PRIVATE_KEY --broadcast
```

For deploying staking separately:
```sh
forge script script/DeployX1Staking.s.sol --fork-url <RPC_URL> --private-key $PRIVATE_KEY --broadcast
```

## Usage
### **Staking X1Coin**
1. Approve the staking contract to spend your tokens:
   ```solidity
   x1Coin.approve(stakingContract, amount);
   ```
2. Stake tokens:
   ```solidity
   staking.stake(amount);
   ```
3. Unstake after **30 days**:
   ```solidity
   staking.unstake();
   ```
4. Check rewards:
   ```solidity
   staking.getStakeInfo(userAddress);
   ```

## Testing
Run unit tests using Foundry:
```sh
forge test
```
## Deployment Information
## Deployment Logs
== Logs ==
  Deployment completed successfully:
  X1Coin deployed to: 0x68B1D87F95878fE05B998F19b66F4baba5De1aed
  Staking contract deployed to: 0x3Aa5ebB10DC797CAC828524e59A333d0A371443c
  Team wallet set to: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
  Community wallet set to: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC

## Setting up 1 EVM.

==========================

Chain 31337

Estimated gas price: 1.120048523 gwei

Estimated total gas used for script: 4783953

Estimated amount required: 0.005358259491751419 ETH

==========================

##### anvil-hardhat
✅  [Success] Hash: 0x22029a7654202680dce29e01e2208f1e6d11bc7ee49bfd2045501c551a6e660c
Contract Address: 0x68B1D87F95878fE05B998F19b66F4baba5De1aed
Block: 7
Paid: 0.00100195355660876 ETH (2013365 gas * 0.497651224 gwei)


##### anvil-hardhat
✅  [Success] Hash: 0x0ac14c6858629302d55ce77da6e540a124f56aafab7ab80dd5911f94ee663a77
Block: 7
Paid: 0.000023095495654616 ETH (46409 gas * 0.497651224 gwei)


##### anvil-hardhat
✅  [Success] Hash: 0x9d181a25c57069229c83240efb1bbee2a8a9dc0297e25f640154d6908f9e14ef
Block: 7
Paid: 0.000023689193564848 ETH (47602 gas * 0.497651224 gwei)


##### anvil-hardhat
✅  [Success] Hash: 0xdbe054779ef84b97a0afaa59110f0490ca633c250402a635b65a39c7106fdda2
Block: 7
Paid: 0.00002371059256748 ETH (47645 gas * 0.497651224 gwei)


##### anvil-hardhat
✅  [Success] Hash: 0xdaba0e90cec99d83fb5a361355e87305792933a13e4e15ac6f388f888583d13d
Contract Address: 0x3Aa5ebB10DC797CAC828524e59A333d0A371443c
Block: 7
Paid: 0.000675666540988264 ETH (1357711 gas * 0.497651224 gwei)


##### anvil-hardhat
✅  [Success] Hash: 0xcfb9e0af32d925f6ec4d3321fc72a946ff7b18fabe5d994c768c6153d0518988
Block: 8
Paid: 0.00006100413773445 ETH (135561 gas * 0.45001245 gwei)

✅ Sequence #1 on anvil-hardhat | Total Paid: 0.001809119517118418 ETH (3648293 gas * avg 0.489711428 gwei)
                                                                                                                                           

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

## Security Measures
- **Reentrancy protection** (`ReentrancyGuard`).
- **Only the staking contract can mint rewards**.
- **Team tokens are time-locked for 6 months**.
- **Safe token transfers using OpenZeppelin’s `SafeERC20`**.

## License
MIT License © 2025

## Contact
For any questions, reach out to **Shreyash Naik**.



