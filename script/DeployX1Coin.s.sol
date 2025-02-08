// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {X1Coin} from "../src/X1Coin.sol";
import {X1Staking} from "../src/X1Staking.sol";

/**
 * @title DeployX1Coin
 * @dev Script for deploying X1Coin and X1Staking contracts.
 */
contract DeployX1Coin is Script {
    /// @notice Error thrown when an invalid address is provided.
    error InvalidAddress();

    /// @notice Emitted when the deployment is successful.
    /// @param x1CoinAddress Address of the deployed X1Coin contract.
    /// @param stakingAddress Address of the deployed X1Staking contract.
    /// @param teamWallet Address of the team wallet.
    /// @param communityWallet Address of the community wallet.
    event DeploymentComplete(
        address x1CoinAddress,
        address stakingAddress,
        address teamWallet,
        address communityWallet
    );

    /**
     * @notice Executes the deployment process.
     * @dev Deploys X1Coin and X1Staking contracts, sets up the staking contract,
     *      and initializes the X1Coin contract for token distribution.
     * @return x1coin The deployed X1Coin contract instance.
     * @return staking The deployed X1Staking contract instance.
     */
    function run() public returns (X1Coin, X1Staking) {
        // Retrieve deployment parameters from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address teamWallet = vm.envAddress("TEAM_WALLET");
        address communityWallet = vm.envAddress("COMMUNITY_WALLET");
        address publicSaleContract = vm.envAddress("PUBLIC_SALE_CONTRACT");

        // Validate that required addresses are not zero
        if (
            teamWallet == address(0) ||
            communityWallet == address(0) ||
            publicSaleContract == address(0)
        ) {
            revert InvalidAddress();
        }

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the X1Coin contract
        X1Coin x1coin = new X1Coin(
            teamWallet,
            communityWallet,
            publicSaleContract
        );

        // Deploy the X1Staking contract
        X1Staking staking = new X1Staking(address(x1coin));

        // Link the staking contract with the X1Coin contract
        x1coin.setStakingContract(address(staking));

        // Initialize X1Coin to distribute tokens (ensuring it is ready for use)
        x1coin.initialize();

        // Emit event confirming successful deployment
        emit DeploymentComplete(
            address(x1coin),
            address(staking),
            teamWallet,
            communityWallet
        );

        vm.stopBroadcast();

        return (x1coin, staking);
    }

    /**
     * @notice Validates the deployment by checking contract configurations.
     * @dev Ensures that X1Coin and X1Staking contracts are correctly linked and initialized.
     * @param x1CoinAddress The address of the deployed X1Coin contract.
     * @param stakingAddress The address of the deployed X1Staking contract.
     * @param teamWallet The expected team wallet address.
     * @param communityWallet The expected community wallet address.
     * @return bool Returns true if the deployment is valid.
     */
    function validateDeployment(
        address x1CoinAddress,
        address stakingAddress,
        address teamWallet,
        address communityWallet
    ) public view returns (bool) {
        X1Coin x1coin = X1Coin(x1CoinAddress);
        X1Staking staking = X1Staking(stakingAddress);

        return (address(staking.x1Token()) == x1CoinAddress &&
            x1coin.teamWallet() == teamWallet &&
            x1coin.communityWallet() == communityWallet &&
            x1coin.stakingContract() == stakingAddress);
    }
}
