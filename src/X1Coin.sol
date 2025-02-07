// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title X1Coin
 * @notice An ERC20 token with predefined allocations for public sale, team, and community.
 * @dev Implements token distribution, staking rewards, and team token locking.
 */
contract X1Coin is ERC20, Ownable {
    /// @notice Total supply of the X1Coin token (1 billion tokens)
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @notice Amount allocated for public sale (50% of total supply)
    uint256 public constant PUBLIC_SALE_AMOUNT = (TOTAL_SUPPLY * 50) / 100;

    /// @notice Amount allocated for team and advisors (30% of total supply)
    uint256 public constant TEAM_ADVISORS_AMOUNT = (TOTAL_SUPPLY * 30) / 100;

    /// @notice Amount allocated for community development (20% of total supply)
    uint256 public constant COMMUNITY_DEVELOPMENT_AMOUNT = (TOTAL_SUPPLY * 20) / 100;

    address public stakingContract;
    uint256 public teamTokensUnlockTime;
    bool public teamTokensDistributed;
    address public teamWallet;
    address public communityWallet;

    event TeamWalletSet(address indexed wallet);
    event CommunityWalletSet(address indexed wallet);
    event TokensDistributed(address indexed recipient, uint256 amount);

    /**
     * @notice Deploys the X1Coin contract and sets an initial team token lock period.
     * @dev The team tokens will be locked for 180 days from deployment.
     */
    constructor() ERC20("X1Coin", "X1C") Ownable(msg.sender) {
        teamTokensUnlockTime = block.timestamp + 180 days; // 6 months lock
    }

    /**
     * @notice Sets the team wallet address.
     * @dev Only callable by the owner.
     * @param _teamWallet The address to set as the team wallet.
     */
    function setTeamWallet(address _teamWallet) external onlyOwner {
        require(_teamWallet != address(0), "Invalid team wallet address");
        teamWallet = _teamWallet;
        emit TeamWalletSet(_teamWallet);
    }

    /**
     * @notice Sets the community wallet address.
     * @dev Only callable by the owner.
     * @param _communityWallet The address to set as the community wallet.
     */
    function setCommunityWallet(address _communityWallet) external onlyOwner {
        require(_communityWallet != address(0), "Invalid community wallet address");
        communityWallet = _communityWallet;
        emit CommunityWalletSet(_communityWallet);
    }

    /**
     * @notice Mints new tokens to a specified address.
     * @dev Can be called by anyone (if permissions are not restricted further).
     * @param to The recipient of the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    /**
     * @notice Distributes the initial token allocation.
     * @dev This function ensures that team and community wallets are set before distributing tokens.
     * @dev Can only be called once by the owner.
     */
    function distributeTokens() external onlyOwner {
        require(!teamTokensDistributed, "Tokens already distributed");
        require(teamWallet != address(0), "Team wallet not set");
        require(communityWallet != address(0), "Community wallet not set");

        _mint(owner(), PUBLIC_SALE_AMOUNT);
        emit TokensDistributed(owner(), PUBLIC_SALE_AMOUNT);

        _mint(teamWallet, TEAM_ADVISORS_AMOUNT);
        emit TokensDistributed(teamWallet, TEAM_ADVISORS_AMOUNT);

        _mint(communityWallet, COMMUNITY_DEVELOPMENT_AMOUNT);
        emit TokensDistributed(communityWallet, COMMUNITY_DEVELOPMENT_AMOUNT);

        teamTokensDistributed = true;
    }

    /**
     * @notice Allows the team to transfer tokens after the lock period has passed.
     * @dev Only callable by the team wallet.
     * @param to The recipient of the transfer.
     * @param amount The amount of tokens to transfer.
     */
    function transferFromTeam(address to, uint256 amount) external {
        require(msg.sender == teamWallet, "Only team wallet can transfer");
        require(block.timestamp >= teamTokensUnlockTime, "Team tokens are locked");
        _transfer(teamWallet, to, amount);
    }

    /**
     * @notice Sets the staking contract address.
     * @dev Only callable by the owner.
     * @param _stakingContract The address of the staking contract.
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid staking contract address");
        stakingContract = _stakingContract;
    }

    /**
     * @notice Mints staking rewards to a specified address.
     * @dev Only callable by the staking contract.
     * @param to The recipient of the staking rewards.
     * @param amount The amount of rewards to mint.
     */
    function mintRewards(address to, uint256 amount) external {
        require(msg.sender == stakingContract, "Only staking contract can mint rewards");
        _mint(to, amount);
    }

    /**
     * @notice Calculates the expected reward based on stake amount and duration.
     * @dev This function is internal and used within staking calculations.
     * @param amount The staked amount.
     * @param duration The duration for which tokens are staked.
     * @return The expected reward amount.
     */
    function calculateExpectedReward(uint256 amount, uint256 duration) internal pure returns (uint256) {
        return (amount * 10 * duration) / (365 days * 100);
    }
}
