// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployX1Coin} from "../../script/DeployX1Coin.s.sol";
import {X1Coin} from "../../src/X1Coin.sol";
import {X1Staking} from "../../src/X1Staking.sol";
import {DeployX1Staking} from "../../script/DeployX1Staking.s.sol";

/**
 * @title DeployX1StakeTest
 * @dev This contract tests the deployment and configuration of X1Coin and X1Staking.
 */
contract DeployStakeTest is Test {
    address deployer;
    X1Coin x1Coin;
    X1Staking staking;

    address teamWallet;
    address communityWallet;
    uint256 deployerPrivateKey;
    DeployX1Staking deployScript;

    /**
     * @dev Sets up the initial state before running tests.
     */
    function setUp() public {
        deployer = makeAddr("deployerAddress");
        teamWallet = makeAddr("teamWallet");
        communityWallet = makeAddr("communityWallet");
        deployerPrivateKey = uint256(keccak256(abi.encodePacked("deployer")));

        vm.startPrank(deployer);
        x1Coin = new X1Coin();
        x1Coin.setTeamWallet(teamWallet);
        x1Coin.setCommunityWallet(communityWallet);

        vm.setEnv("X1COIN_ADDRESS", vm.toString(address(x1Coin)));
        deployScript = new DeployX1Staking();
        staking = new X1Staking(address(x1Coin));
        vm.stopPrank();
    }

    /**
     * @dev Tests the basic deployment properties of X1Coin and X1Staking.
     */
    function testDeploymentBasics() public view {
        assertEq(x1Coin.name(), "X1Coin");
        assertEq(x1Coin.symbol(), "X1C");
        assertEq(address(staking.x1Token()), address(x1Coin));
    }

    /**
     * @dev Ensures that environment variables cannot be set to invalid values.
     */
    function testDeploymentEnvironmentVariables() public {
        vm.expectRevert();
        vm.setEnv("TEAM_WALLET", vm.toString(address(0)));

        vm.expectRevert();
        vm.setEnv("COMMUNITY_WALLET", vm.toString(address(0)));

        vm.expectRevert();
        vm.setEnv("PRIVATE_KEY", "");
    }

    /**
     * @dev Tests whether the team and community wallets are correctly assigned.
     */
    function testWalletConfiguration() public view {
        assertEq(x1Coin.teamWallet(), teamWallet, "Team wallet should be correctly set");
        assertEq(x1Coin.communityWallet(), communityWallet, "Community wallet should be correctly set");
    }

    /**
     * @dev Tests the token distribution mechanism to ensure tokens are properly allocated.
     */
    function testTokenDistribution() public {
        vm.prank(deployer);
        x1Coin.distributeTokens();
        assertTrue(x1Coin.balanceOf(deployer) > 0, "Deployer should have public sale tokens");
        assertTrue(x1Coin.balanceOf(teamWallet) > 0, "Team wallet should receive tokens");
        assertTrue(x1Coin.balanceOf(communityWallet) > 0, "Community wallet should receive tokens");
    }

    /**
     * @dev Tests whether the staking contract is correctly assigned to X1Coin.
     */
    function testStakingContractConfiguration() public {
        vm.prank(deployer);
        x1Coin.setStakingContract(address(staking));

        assertEq(x1Coin.stakingContract(), address(staking), "Staking contract should be set correctly");
    }

    /**
     * @dev Validates that key deployment parameters are correct.
     */
    function testDeploymentValidation() public view {
        assertTrue(address(x1Coin) != address(0), "X1Coin should be deployed");
        assertTrue(address(staking) != address(0), "Staking contract should be deployed");
        assertEq(address(staking.x1Token()), address(x1Coin), "Staking contract should reference X1Coin");
    }

    /**
     * @dev Tests the deployment of multiple staking contracts to ensure uniqueness.
     */
    function testMultipleStakingContractDeployments() public {
        X1Staking staking1 = new X1Staking(address(x1Coin));
        X1Staking staking2 = new X1Staking(address(x1Coin));

        assertTrue(address(staking1) != address(staking2), "Multiple staking contracts should have unique addresses");
        assertEq(
            address(staking1.x1Token()),
            address(staking2.x1Token()),
            "Both staking contracts should reference the same token"
        );
        vm.stopPrank();
    }
}
