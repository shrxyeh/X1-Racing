// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {X1Coin} from "../../src/X1Coin.sol";
import {X1Staking} from "../../src/X1Staking.sol";
import {console} from "forge-std/console.sol";

contract X1StakingTest is Test {
    X1Coin public x1coin;
    X1Staking public staking;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        x1coin = new X1Coin();
        staking = new X1Staking(address(x1coin));

        x1coin.setTeamWallet(address(0x2));
        x1coin.setCommunityWallet(address(0x3));
        x1coin.distributeTokens();

        x1coin.setStakingContract(address(staking));
        x1coin.transfer(user, 1000 * 10 ** 18);
    }

    function testStakingZeroTokens() public {
        vm.startPrank(user);
        vm.expectRevert("Cannot stake 0 tokens");
        staking.stake(0);
        vm.stopPrank();
    }

    function testStaking() public {
        uint256 stakeAmount = 100 * 10 ** 18;

        vm.startPrank(user);
        x1coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        (uint256 amount, uint256 stakingTime,,) = staking.getStakeInfo(user);
        assertEq(amount, stakeAmount);
        assertEq(stakingTime, block.timestamp);
    }

    function testMultipleStakes() public {
        uint256 firstStakeAmount = 100 * 10 ** 18;
        uint256 secondStakeAmount = 50 * 10 ** 18;

        vm.startPrank(user);
        x1coin.approve(address(staking), firstStakeAmount + secondStakeAmount);
        staking.stake(firstStakeAmount);
        vm.warp(block.timestamp + 15 days);
        staking.stake(secondStakeAmount);
        vm.stopPrank();

        (uint256 amount,,,) = staking.getStakeInfo(user);
        assertEq(amount, firstStakeAmount + secondStakeAmount);
    }

    function testRewardsReinvestment() public {
        uint256 stakeAmount = 100 * 10 ** 18;

        vm.startPrank(user);
        vm.expectRevert("No tokens staked");
        staking.reinvestRewards();
        x1coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.warp(block.timestamp + 31 days);

        (uint256 initialAmount,,,) = staking.getStakeInfo(user);
        staking.reinvestRewards();
        (uint256 newAmount,,,) = staking.getStakeInfo(user);
        assertGt(newAmount, initialAmount);

        vm.stopPrank();
    }

    function testStakingTierRewards() public {
        uint256 stakeAmount = 100 * 10 ** 18;

        vm.startPrank(user);
        x1coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        uint256[] memory stakingDurations = new uint256[](4);
        stakingDurations[0] = 0;
        stakingDurations[1] = 91 days;
        stakingDurations[2] = 181 days;
        stakingDurations[3] = 366 days;

        for (uint256 i = 0; i < stakingDurations.length; i++) {
            vm.warp(block.timestamp + stakingDurations[i]);
            (,, uint256 pendingRewards, uint256 rewardMultiplier) = staking.getStakeInfo(user);
            console.log("Duration:", stakingDurations[i]);
            console.log("Reward Multiplier:", rewardMultiplier);
            console.log("Pending Rewards:", pendingRewards);
        }
        vm.stopPrank();
    }

    function testUnstakeAfterMinimumPeriod() public {
        uint256 stakeAmount = 100 * 10 ** 18;

        vm.startPrank(user);
        x1coin.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        vm.expectRevert("Minimum staking period not met");
        staking.unstake();
        vm.warp(block.timestamp + 31 days);

        (uint256 amount, uint256 stakingTime, uint256 pendingRewards,) = staking.getStakeInfo(user);
        console.log("Stake Amount:", amount);
        console.log("Staking Time:", stakingTime);
        console.log("Pending Rewards:", pendingRewards);

        uint256 initialBalance = x1coin.balanceOf(user);
        staking.unstake();
        uint256 finalBalance = x1coin.balanceOf(user);

        console.log("Initial Balance:", initialBalance);
        console.log("Final Balance:", finalBalance);

        assertGt(finalBalance, initialBalance);

        uint256 expectedReward = (stakeAmount * 10 * 31) / (365 * 100);
        uint256 actualReward = finalBalance - initialBalance - stakeAmount;

        console.log("Expected Reward:", expectedReward);
        console.log("Actual Reward:", actualReward);
        assertApproxEqRel(actualReward, expectedReward, 1e16);

        vm.stopPrank();
    }
}
