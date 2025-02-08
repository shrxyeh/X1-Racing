// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {X1Coin} from "../../src/X1Coin.sol";
import {X1Staking} from "../../src/X1Staking.sol";
import {DeployX1Staking} from "../../script/DeployX1Staking.s.sol";

contract X1StakingTest is Test {
    X1Coin public x1Coin;
    X1Staking public staking;
    address public owner;
    address public user1;
    address public user2;
    address public teamWallet;
    address public communityWallet;
    address public publicSaleContract;

    // Events to test
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsReinvested(address indexed user, uint256 amount);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        teamWallet = makeAddr("teamWallet");
        communityWallet = makeAddr("communityWallet");
        publicSaleContract = makeAddr("publicSaleContract");

        // Deploy X1Coin
        x1Coin = new X1Coin(teamWallet, communityWallet, publicSaleContract);

        // Setup X1Coin initial state
        if (x1Coin.teamWallet() == address(0)) {
            x1Coin.setTeamWallet(teamWallet);
        }
        if (x1Coin.communityWallet() == address(0)) {
            x1Coin.setCommunityWallet(communityWallet);
        }
        if (x1Coin.publicSaleContract() == address(0)) {
            x1Coin.setPublicSaleContract(publicSaleContract);
        }

        // Initialize the contract to mint and distribute tokens
        x1Coin.initialize(); // Add this line

        // Deploy Staking contract
        staking = new X1Staking(address(x1Coin));
        x1Coin.setStakingContract(address(staking));

        // Fund users for testing by transferring from publicSaleContract
        vm.startPrank(publicSaleContract);
        x1Coin.transfer(user1, 1000000 * 1e18);
        x1Coin.transfer(user2, 1000000 * 1e18);
        vm.stopPrank();
    }

    // Basic Staking Tests
    function testStaking() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(user1);
        x1Coin.approve(address(staking), stakeAmount);

        vm.expectEmit(true, false, false, true);
        emit Staked(user1, stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        (uint256 amount, , , ) = staking.getStakeInfo(user1);
        assertEq(amount, stakeAmount, "Stake amount mismatch");
    }

    // Test minimum staking period
    function testCannotUnstakeBeforeMinimumPeriod() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(user1);
        x1Coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        vm.expectRevert("Minimum staking period not met");
        staking.unstake();
        vm.stopPrank();
    }

    // Test reward calculation
    function testRewardCalculation() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(user1);
        x1Coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Fast forward 90 days to reach Tier 1
        vm.warp(block.timestamp + 90 days);

        uint256 pendingRewards = staking.calculatePendingRewards(user1);
        assertTrue(pendingRewards > 0, "No rewards accumulated");

        vm.stopPrank();
    }

    // Test reward tiers
    function testRewardTiers() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(user1);
        x1Coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Check base multiplier
        (, , , uint256 baseMultiplier) = staking.getStakeInfo(user1);
        assertEq(baseMultiplier, 1000, "Incorrect base multiplier");

        // Check Tier 1 multiplier (90 days)
        vm.warp(block.timestamp + 90 days);
        (, , , uint256 tier1Multiplier) = staking.getStakeInfo(user1);
        assertEq(tier1Multiplier, 1250, "Incorrect Tier 1 multiplier");

        // Check Tier 2 multiplier (180 days)
        vm.warp(block.timestamp + 90 days);
        (, , , uint256 tier2Multiplier) = staking.getStakeInfo(user1);
        assertEq(tier2Multiplier, 1500, "Incorrect Tier 2 multiplier");

        // Check Tier 3 multiplier (365 days)
        vm.warp(block.timestamp + 185 days);
        (, , , uint256 tier3Multiplier) = staking.getStakeInfo(user1);
        assertEq(tier3Multiplier, 2000, "Incorrect Tier 3 multiplier");

        vm.stopPrank();
    }

    // Test reward reinvestment
    function testRewardReinvestment() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(user1);
        x1Coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Fast forward 90 days
        vm.warp(block.timestamp + 90 days);

        uint256 pendingRewardsBefore = staking.calculatePendingRewards(user1);
        vm.expectEmit(true, false, false, true);
        emit RewardsReinvested(user1, pendingRewardsBefore);
        staking.reinvestRewards();

        (uint256 newStakeAmount, , , ) = staking.getStakeInfo(user1);
        assertEq(
            newStakeAmount,
            stakeAmount + pendingRewardsBefore,
            "Incorrect reinvestment amount"
        );

        vm.stopPrank();
    }

    // Test complete unstaking process
    function testCompleteUnstaking() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(user1);
        x1Coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Wait for minimum staking period plus some extra time for rewards
        vm.warp(block.timestamp + 31 days);

        uint256 pendingRewards = staking.calculatePendingRewards(user1);
        uint256 balanceBefore = x1Coin.balanceOf(user1);

        vm.expectEmit(true, false, false, true);
        emit Unstaked(user1, stakeAmount, pendingRewards);
        staking.unstake();

        uint256 balanceAfter = x1Coin.balanceOf(user1);
        assertEq(
            balanceAfter,
            balanceBefore + stakeAmount + pendingRewards,
            "Incorrect final balance"
        );

        vm.stopPrank();
    }

    // Test maximum rewards cap
    function testMaximumRewardsCap() public {
        uint256 stakeAmount = 1000000 * 1e18; // Large stake to test cap

        vm.startPrank(user1);
        x1Coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Fast forward a year
        vm.warp(block.timestamp + 365 days);

        uint256 pendingRewards = staking.calculatePendingRewards(user1);
        assertTrue(
            pendingRewards <= staking.MAX_ANNUAL_REWARDS(),
            "Rewards exceeded maximum cap"
        );

        vm.stopPrank();
    }

    // Test multiple users staking
    function testMultipleUsersStaking() public {
        uint256 stakeAmount = 1000 * 1e18;

        // User 1 stakes
        vm.startPrank(user1);
        x1Coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // User 2 stakes
        vm.startPrank(user2);
        x1Coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Fast forward 90 days
        vm.warp(block.timestamp + 90 days);

        uint256 user1Rewards = staking.calculatePendingRewards(user1);
        uint256 user2Rewards = staking.calculatePendingRewards(user2);

        assertEq(
            user1Rewards,
            user2Rewards,
            "Rewards should be equal for equal stakes"
        );
    }

    // Test zero amount staking
    function testZeroAmountStaking() public {
        vm.startPrank(user1);
        vm.expectRevert("Cannot stake 0 tokens");
        staking.stake(0);
        vm.stopPrank();
    }

    // Test reinvesting with no rewards
    function testReinvestWithNoRewards() public {
        uint256 stakeAmount = 1000 * 1e18;

        vm.startPrank(user1);
        x1Coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        vm.expectRevert("No rewards to reinvest");
        staking.reinvestRewards();
        vm.stopPrank();
    }

    // Helper function to verify token balances
    function assertTokenBalance(
        address account,
        uint256 expectedBalance
    ) internal view {
        uint256 actualBalance = x1Coin.balanceOf(account);
        assertEq(actualBalance, expectedBalance, "Token balance mismatch");
    }
}
