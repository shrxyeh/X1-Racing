// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {X1Coin} from "./X1Coin.sol";

/**
 * @title X1Staking
 * @dev A staking contract for X1Coin that allows users to stake tokens and earn rewards.
 */
contract X1Staking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Stake {
        uint256 amount;
        uint256 startTimestamp;
        uint256 lastRewardCalculationTime;
        uint256 accumulatedRewards;
    }

    X1Coin public immutable x1Token;
    address public owner;

    // Staking configuration parameters
    uint256 public constant MINIMUM_STAKING_PERIOD = 30 days;
    uint256 public constant BASE_ANNUAL_REWARD_RATE = 10; // 10% base rate
    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public constant MAX_REWARD_MULTIPLIER = 2; // Maximum 2x rewards for long-term staking

    // Staking tiers with reward multipliers
    uint256[3] public stakingTiers = [
        90 days, // Tier 1: 1.25x rewards
        180 days, // Tier 2: 1.5x rewards
        365 days // Tier 3: 2x rewards
    ];
    uint256[4] public rewardMultipliers = [
        1000, // Base: 1x
        1250, // Tier 1: 1.25x
        1500, // Tier 2: 1.5x
        2000 // Tier 3: 2x
    ];

    mapping(address => Stake) public stakes;
    uint256 public totalStakedTokens;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsReinvested(address indexed user, uint256 amount);

    /**
     * @dev Constructor initializes the staking contract.
     * @param _x1Token Address of the X1Coin token contract.
     */
    constructor(address _x1Token) {
        require(_x1Token != address(0), "Invalid token address");
        x1Token = X1Coin(_x1Token);
        owner = msg.sender;
    }

    /**
     * @notice Allows a user to stake X1 tokens.
     * @param amount The number of tokens to stake.
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0 tokens");

        Stake storage userStake = stakes[msg.sender];

        IERC20(address(x1Token)).safeTransferFrom(msg.sender, address(this), amount);

        if (userStake.amount > 0) {
            uint256 pendingRewards = calculatePendingRewards(msg.sender);
            userStake.accumulatedRewards += pendingRewards;
        }

        userStake.amount += amount;
        userStake.lastRewardCalculationTime = block.timestamp;
        if (userStake.startTimestamp == 0) {
            userStake.startTimestamp = block.timestamp;
        }

        totalStakedTokens += amount;
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Allows a user to reinvest their accumulated rewards into staking.
     */
    function reinvestRewards() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No tokens staked");

        uint256 pendingRewards = calculatePendingRewards(msg.sender);
        require(pendingRewards > 0, "No rewards to reinvest");

        userStake.lastRewardCalculationTime = block.timestamp;
        userStake.amount += pendingRewards;
        totalStakedTokens += pendingRewards;

        emit RewardsReinvested(msg.sender, pendingRewards);
    }

    /**
     * @notice Allows a user to unstake their tokens and claim rewards after the minimum staking period.
     */
    function unstake() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No tokens staked");
        require(block.timestamp >= userStake.startTimestamp + MINIMUM_STAKING_PERIOD, "Minimum staking period not met");

        uint256 pendingRewards = calculatePendingRewards(msg.sender);
        uint256 totalRewards = userStake.accumulatedRewards + pendingRewards;
        uint256 originalStakeAmount = userStake.amount;

        totalStakedTokens -= userStake.amount;
        userStake.amount = 0;
        userStake.startTimestamp = 0;
        userStake.lastRewardCalculationTime = 0;
        userStake.accumulatedRewards = 0;

        x1Token.mintRewards(msg.sender, totalRewards);
        IERC20(address(x1Token)).safeTransfer(msg.sender, originalStakeAmount);

        emit Unstaked(msg.sender, originalStakeAmount, totalRewards);
        emit RewardClaimed(msg.sender, totalRewards);
    }

    /**
     * @notice Calculates pending rewards for a user.
     * @param user Address of the user.
     * @return The pending reward amount.
     */
    function calculatePendingRewards(address user) public view returns (uint256) {
        Stake storage userStake = stakes[user];
        if (userStake.amount == 0) return 0;

        uint256 timeElapsed = block.timestamp - userStake.lastRewardCalculationTime;
        uint256 stakingDuration = block.timestamp - userStake.startTimestamp;

        uint256 rewardMultiplier = rewardMultipliers[0];
        for (uint256 i = 0; i < stakingTiers.length; i++) {
            if (stakingDuration >= stakingTiers[i]) {
                rewardMultiplier = rewardMultipliers[i + 1];
            }
        }

        uint256 annualReward =
            (userStake.amount * BASE_ANNUAL_REWARD_RATE * rewardMultiplier * REWARD_PRECISION) / (100 * 1000);
        uint256 pendingRewards = (annualReward * timeElapsed) / (365 days * REWARD_PRECISION);

        return pendingRewards;
    }

    /**
     * @notice Returns staking information for a given user.
     * @param user Address of the user.
     * @return amount The amount staked.
     * @return stakingTime The timestamp when staking started.
     * @return pendingRewards The pending reward amount.
     * @return rewardMultiplier The applicable reward multiplier.
     */
    function getStakeInfo(address user)
        external
        view
        returns (uint256 amount, uint256 stakingTime, uint256 pendingRewards, uint256 rewardMultiplier)
    {
        Stake memory userStake = stakes[user];
        amount = userStake.amount;
        stakingTime = userStake.startTimestamp;
        pendingRewards = calculatePendingRewards(user);

        uint256 stakingDuration = block.timestamp - userStake.startTimestamp;
        uint256 multiplierIndex = 0;
        for (uint256 i = 0; i < stakingTiers.length; i++) {
            if (stakingDuration >= stakingTiers[i]) {
                multiplierIndex = i + 1;
            }
        }
        rewardMultiplier = rewardMultipliers[multiplierIndex] / 1000.0;
    }
}
