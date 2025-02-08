// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {X1Coin} from "../src/X1Coin.sol";
import {X1Staking} from "../src/X1Staking.sol";

/**
 * @title DeployX1Staking
 * @dev Script for deploying the X1Staking contract and linking it with X1Coin.
 */
contract DeployX1Staking is Script {
    /**
     * @notice Deploys the X1Staking contract.
     * @dev Retrieves the X1Coin contract address from environment variables,
     *      deploys the staking contract, and sets the staking contract address in X1Coin.
     * @return staking The deployed X1Staking contract instance.
     */
    function run() external returns (X1Staking) {
        // Retrieve the X1Coin contract address from environment variables
        address x1CoinAddress = vm.envAddress("X1COIN_ADDRESS");

        vm.startBroadcast();

        // Deploy the X1Staking contract
        X1Staking staking = new X1Staking(x1CoinAddress);

        // Link the staking contract with the X1Coin contract
        X1Coin(x1CoinAddress).setStakingContract(address(staking));

        vm.stopBroadcast();

        return staking;
    }
}
