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

    uint256 public constant MINIMUM_STAKING_PERIOD = 30 days;
    uint256 public constant BASE_ANNUAL_REWARD_RATE = 10; // 10% base rate
    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public constant MAX_REWARD_MULTIPLIER = 2; // Maximum 2x rewards

    // Reward caps aligned with total supply (5% of total supply for rewards)
    uint256 public constant MAX_TOTAL_REWARDS = 50_000_000 * 1e18; // 50M tokens max total rewards (5% of total supply)
    uint256 public constant MAX_ANNUAL_REWARDS = 10_000_000 * 1e18; // 10M tokens max annual rewards (1% of total supply)

    uint256 public totalRewardsMinted;
    uint256 public annualRewardsMinted;
    uint256 public lastAnnualResetTime;
    uint256 public lastRewardCalculationTimestamp;

    // Reward rate decay parameters
    uint256 public constant REWARD_REDUCTION_PERIOD = 365 days;
    uint256 public constant REWARD_REDUCTION_RATE = 25; // 25% reduction per year
    uint256 public rewardRateMultiplier = 100; // Starts at 100% (scaled by 100)
    uint256 public lastRewardRateUpdateTime;

    // Rward staking tiers
    uint256[3] public stakingTiers = [90 days, 180 days, 365 days];
    uint256[4] public rewardMultipliers = [1000, 1250, 1500, 2000];

    mapping(address => Stake) public stakes;
    uint256 public totalStakedTokens;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsReinvested(address indexed user, uint256 amount);
    event AnnualRewardsReset(uint256 timestamp);
    event RewardRateUpdated(uint256 newRate);

    /**
     * @dev Constructor initializes the staking contract.
     * @param _x1Token Address of the X1Coin token contract.
     */
    constructor(address _x1Token) {
        require(_x1Token != address(0), "Invalid token address");
        x1Token = X1Coin(_x1Token);
        lastRewardCalculationTimestamp = block.timestamp;
        lastAnnualResetTime = block.timestamp;
        lastRewardRateUpdateTime = block.timestamp;
    }

    /**
     * @notice Updates the reward rate multiplier based on time elapsed since last update.
     */

    function updateRewardRate() internal {
        uint256 timeElapsed = block.timestamp - lastRewardRateUpdateTime;
        if (timeElapsed >= REWARD_REDUCTION_PERIOD) {
            uint256 periods = timeElapsed / REWARD_REDUCTION_PERIOD;
            for (uint256 i = 0; i < periods; i++) {
                rewardRateMultiplier =
                    (rewardRateMultiplier * (100 - REWARD_REDUCTION_RATE)) /
                    100;
            }
            lastRewardRateUpdateTime = block.timestamp;
            emit RewardRateUpdated(rewardRateMultiplier);
        }
    }

    /**
     * @notice Resets annual rewards tracking if a year has passed
     */
    function _checkAndResetAnnualRewards() internal {
        if (block.timestamp >= lastAnnualResetTime + 365 days) {
            annualRewardsMinted = 0;
            lastAnnualResetTime = block.timestamp;
            emit AnnualRewardsReset(block.timestamp);
        }
    }

    /**
     * @notice Allows a user to stake X1 tokens.
     * @param amount The number of tokens to stake.
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0 tokens");

        Stake storage userStake = stakes[msg.sender];

        IERC20(address(x1Token)).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

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
        require(
            block.timestamp >=
                userStake.startTimestamp + MINIMUM_STAKING_PERIOD,
            "Minimum staking period not met"
        );

        uint256 pendingRewards = calculatePendingRewards(msg.sender);
        uint256 totalRewards = userStake.accumulatedRewards + pendingRewards;
        uint256 originalStakeAmount = userStake.amount;

        totalStakedTokens -= userStake.amount;
        delete stakes[msg.sender];

        // Update total rewards minted
        totalRewardsMinted += totalRewards;

        // Mint rewards and transfer staked tokens
        if (totalRewards > 0) {
            x1Token.mintRewards(msg.sender, totalRewards);
        }
        IERC20(address(x1Token)).safeTransfer(msg.sender, originalStakeAmount);

        emit Unstaked(msg.sender, originalStakeAmount, totalRewards);
        emit RewardClaimed(msg.sender, totalRewards);
    }

    /**
     * @notice Calculates pending rewards for a user with supply caps
     * @param user Address of the user
     * @return The pending reward amount
     */
    function calculatePendingRewards(
        address user
    ) public view returns (uint256) {
        Stake storage userStake = stakes[user];
        if (userStake.amount == 0) return 0;

        uint256 timeElapsed = block.timestamp -
            userStake.lastRewardCalculationTime;
        uint256 stakingDuration = block.timestamp - userStake.startTimestamp;

        if (stakingDuration == 0) return 0;

        // Get reward multiplier based on staking duration
        uint256 rewardMultiplier = rewardMultipliers[0];
        for (uint256 i = 0; i < stakingTiers.length; i++) {
            if (stakingDuration >= stakingTiers[i]) {
                rewardMultiplier = rewardMultipliers[i + 1];
            }
        }

        // Apply reward rate decay
        uint256 currentRewardRate = (BASE_ANNUAL_REWARD_RATE *
            rewardRateMultiplier) / 100;

        // Calculate base rewards with decay
        uint256 annualReward = (userStake.amount *
            currentRewardRate *
            rewardMultiplier *
            REWARD_PRECISION) / (100 * 1000);
        uint256 pendingRewards = (annualReward * timeElapsed) /
            (365 days * REWARD_PRECISION);

        // Check against total rewards cap
        if (totalRewardsMinted + pendingRewards > MAX_TOTAL_REWARDS) {
            return 0;
        }

        // Check against annual rewards cap
        if (annualRewardsMinted + pendingRewards > MAX_ANNUAL_REWARDS) {
            return 0;
        }

        return pendingRewards;
    }

    /**
     * @notice Claims rewards and updates reward tracking
     * @param rewards Amount of rewards to claim
     */
    function _claimRewards(uint256 rewards) internal {
        if (rewards == 0) return;

        _checkAndResetAnnualRewards();

        require(
            totalRewardsMinted + rewards <= MAX_TOTAL_REWARDS,
            "Exceeds total rewards cap"
        );
        require(
            annualRewardsMinted + rewards <= MAX_ANNUAL_REWARDS,
            "Exceeds annual rewards cap"
        );

        totalRewardsMinted += rewards;
        annualRewardsMinted += rewards;
        x1Token.mintRewards(msg.sender, rewards);

        emit RewardClaimed(msg.sender, rewards);
    }

    /**
     * @notice Returns staking information for a given user.
     * @param user Address of the user.
     * @return amount The amount staked.
     * @return stakingTime The timestamp when staking started.
     * @return pendingRewards The pending reward amount.
     * @return rewardMultiplier The applicable reward multiplier.
     */
    function getStakeInfo(
        address user
    )
        external
        view
        returns (
            uint256 amount,
            uint256 stakingTime,
            uint256 pendingRewards,
            uint256 rewardMultiplier
        )
    {
        Stake memory userStake = stakes[user];
        amount = userStake.amount;
        stakingTime = userStake.startTimestamp;

        if (amount == 0 || stakingTime == 0) {
            return (0, 0, 0, 0);
        }

        pendingRewards = calculatePendingRewards(user);

        uint256 stakingDuration = block.timestamp - userStake.startTimestamp;
        uint256 multiplierIndex = 0;
        if (stakingDuration == 0) {
            stakingDuration = 1;
        }

        for (uint256 i = 0; i < stakingTiers.length; i++) {
            if (stakingDuration >= stakingTiers[i]) {
                multiplierIndex = i + 1;
            }
        }

        if (multiplierIndex >= rewardMultipliers.length) {
            multiplierIndex = rewardMultipliers.length - 1;
        }

        rewardMultiplier = rewardMultipliers[multiplierIndex];
    }
}
