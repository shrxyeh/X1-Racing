// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {X1Coin} from "../src/X1Coin.sol";
import {X1Staking} from "../src/X1Staking.sol";

contract DeployX1Staking is Script {
    function run() external returns (X1Staking) {
        address x1CoinAddress = vm.envAddress("X1COIN_ADDRESS");

        vm.startBroadcast();

        // Deploy Staking Contract
        X1Staking staking = new X1Staking(x1CoinAddress);

        // Set the staking contract address in X1Coin
        X1Coin(x1CoinAddress).setStakingContract(address(staking));

        vm.stopBroadcast();

        return staking;
    }
}
