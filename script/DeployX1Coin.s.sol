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
    error InvalidAddress();
    error DeploymentFailed();
    error MissingEnvironmentVariable(string varName);

    /// @notice Emitted when the deployment is successful.
    /// @param x1Coin Address of the deployed X1Coin contract.
    /// @param staking Address of the deployed X1Staking contract.
    /// @param teamWallet Address of the team wallet.
    /// @param communityWallet Address of the community wallet.
    event DeploymentComplete(address x1Coin, address staking, address teamWallet, address communityWallet);

    /**
     * @notice Executes the deployment process.
     * @dev Deploys X1Coin and X1Staking contracts and sets up initial configurations.
     */
    function run() external {
        try vm.envUint("PRIVATE_KEY") returns (uint256 deployerPrivateKey) {
            address teamWallet;
            address communityWallet;

            try vm.envAddress("TEAM_WALLET") returns (address _teamWallet) {
                teamWallet = _teamWallet;
            } catch {
                console.log("TEAM_WALLET environment variable not set");
                revert MissingEnvironmentVariable("TEAM_WALLET");
            }

            try vm.envAddress("COMMUNITY_WALLET") returns (address _communityWallet) {
                communityWallet = _communityWallet;
            } catch {
                console.log("COMMUNITY_WALLET environment variable not set");
                revert MissingEnvironmentVariable("COMMUNITY_WALLET");
            }

            // Validate addresses
            if (teamWallet == address(0) || communityWallet == address(0)) {
                console.log("Invalid wallet addresses");
                revert InvalidAddress();
            }

            vm.startBroadcast(deployerPrivateKey);

            // Deploy X1Coin
            X1Coin x1coin = new X1Coin();
            if (address(x1coin) == address(0)) {
                revert DeploymentFailed();
            }

            // Deploy X1Staking contract
            X1Staking staking = new X1Staking(address(x1coin));
            if (address(staking) == address(0)) {
                revert DeploymentFailed();
            }

            // Configure X1Coin
            x1coin.setTeamWallet(teamWallet);
            x1coin.setCommunityWallet(communityWallet);
            x1coin.setStakingContract(address(staking));

            // Initialize token distribution
            x1coin.distributeTokens();

            vm.stopBroadcast();

            // Log deployment details
            console.log("Deployment completed successfully:");
            console.log("X1Coin deployed to:", address(x1coin));
            console.log("Staking contract deployed to:", address(staking));
            console.log("Team wallet set to:", teamWallet);
            console.log("Community wallet set to:", communityWallet);

            emit DeploymentComplete(address(x1coin), address(staking), teamWallet, communityWallet);
        } catch {
            console.log("PRIVATE_KEY environment variable not set");
            revert MissingEnvironmentVariable("PRIVATE_KEY");
        }
    }

    /**
     * @notice Validates the deployment by checking contract configurations.
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
    ) external view returns (bool) {
        X1Coin x1coin = X1Coin(x1CoinAddress);
        X1Staking staking = X1Staking(stakingAddress);

        require(x1coin.teamWallet() == teamWallet, "Invalid team wallet");
        require(x1coin.communityWallet() == communityWallet, "Invalid community wallet");
        require(x1coin.stakingContract() == stakingAddress, "Invalid staking contract");
        require(address(staking.x1Token()) == x1CoinAddress, "Invalid token address in staking");

        return true;
    }
}
