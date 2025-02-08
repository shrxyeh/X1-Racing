// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title X1Coin
 * @notice An ERC20 token with allocations for public sale, team, and community.
 * @dev Implements token distribution, staking rewards, and team token locking.
 */
contract X1Coin is ERC20, Ownable, ReentrancyGuard {
    /// @notice Total supply of X1Coin (1 billion tokens)
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @notice Allocation for public sale (50%)
    uint256 public constant PUBLIC_SALE_AMOUNT = (TOTAL_SUPPLY * 50) / 100;

    /// @notice Allocation for team and advisors (30%)
    uint256 public constant TEAM_ADVISORS_AMOUNT = (TOTAL_SUPPLY * 30) / 100;

    /// @notice Allocation for community development (20%)
    uint256 public constant COMMUNITY_DEVELOPMENT_AMOUNT =
        (TOTAL_SUPPLY * 20) / 100;

    /// @notice Allocation for staking rewards (5%)
    uint256 public constant STAKING_REWARDS_AMOUNT = (TOTAL_SUPPLY * 5) / 100;

    /// @notice Address of the staking contract
    address public stakingContract;

    /// @notice Address of the public sale contract
    address public publicSaleContract;

    /// @notice Address of the team wallet
    address public teamWallet;

    /// @notice Address of the community wallet
    address public communityWallet;

    /// @notice Timestamp when team tokens unlock
    uint256 public teamTokensUnlockTime;

    /// @notice Tracks the total number of tokens minted
    uint256 public totalTokensMinted;

    /// @notice Tracks whether tokens have been distributed
    bool public tokensDistributed;

    /// @notice Tracks whether the contract has been initialized
    bool public initialized;

    /// @notice Tracks total staking rewards minted
    uint256 public totalStakingRewardsMinted;

    /// @dev Events for transparency and tracking state changes
    event TeamWalletSet(address indexed wallet);
    event CommunityWalletSet(address indexed wallet);
    event PublicSaleContractSet(address indexed saleContract);
    event TokensDistributed(address indexed recipient, uint256 amount);
    event StakingRewardMinted(address indexed recipient, uint256 amount);
    event ContractInitialized();

    /// @dev Restricts access to only the staking contract
    modifier onlyStakingContract() {
        require(
            msg.sender == stakingContract,
            "Only staking contract can call"
        );
        _;
    }

    /**
     * @notice Deploys the X1Coin contract
     * @param _teamWallet The wallet address for the team and advisors
     * @param _communityWallet The wallet address for community allocations
     * @param _publicSaleContract The contract address for public sale
     */
    constructor(
        address _teamWallet,
        address _communityWallet,
        address _publicSaleContract
    ) ERC20("X1Coin", "X1C") Ownable(msg.sender) {
        require(_teamWallet != address(0), "Invalid team wallet");
        require(_communityWallet != address(0), "Invalid community wallet");

        teamWallet = _teamWallet;
        communityWallet = _communityWallet;
        publicSaleContract = _publicSaleContract;
        teamTokensUnlockTime = block.timestamp + 180 days;
    }

    /**
     * @notice Initializes the contract and distributes initial token allocations.
     * @dev Can only be called once after the public sale contract is set.
     */
    function initialize() external onlyOwner {
        require(!initialized, "Already initialized");
        require(publicSaleContract != address(0), "Public sale not set");
        require(!tokensDistributed, "Tokens already distributed");

        // Distribute token allocations
        _mint(teamWallet, TEAM_ADVISORS_AMOUNT);
        _mint(communityWallet, COMMUNITY_DEVELOPMENT_AMOUNT);
        _mint(publicSaleContract, PUBLIC_SALE_AMOUNT);

        tokensDistributed = true;
        initialized = true;

        emit TokensDistributed(teamWallet, TEAM_ADVISORS_AMOUNT);
        emit TokensDistributed(communityWallet, COMMUNITY_DEVELOPMENT_AMOUNT);
        emit TokensDistributed(publicSaleContract, PUBLIC_SALE_AMOUNT);
        emit ContractInitialized();
    }

    /**
     * @notice Sets the team wallet address.
     * @dev Can only be set once.
     * @param _teamWallet The new team wallet address.
     */
    function setTeamWallet(address _teamWallet) external onlyOwner {
        require(_teamWallet != address(0), "Invalid address");
        require(teamWallet == address(0), "Team wallet already set");
        teamWallet = _teamWallet;
        emit TeamWalletSet(teamWallet);
    }

    /**
     * @notice Sets the community wallet address.
     * @dev Can only be set once.
     * @param _communityWallet The new community wallet address.
     */
    function setCommunityWallet(address _communityWallet) external onlyOwner {
        require(_communityWallet != address(0), "Invalid address");
        require(communityWallet == address(0), "Community wallet already set");
        communityWallet = _communityWallet;
        emit CommunityWalletSet(communityWallet);
    }

    /**
     * @notice Sets the public sale contract address.
     * @dev Can only be set before initialization.
     * @param _publicSaleContract The public sale contract address.
     */
    function setPublicSaleContract(
        address _publicSaleContract
    ) external onlyOwner {
        require(!initialized, "Contract already initialized");
        require(
            publicSaleContract == address(0),
            "Public sale contract already set"
        );
        require(_publicSaleContract != address(0), "Invalid address");
        publicSaleContract = _publicSaleContract;
        emit PublicSaleContractSet(publicSaleContract);
    }

    /**
     * @notice Allows the team to transfer tokens after the lock period.
     * @param to Recipient address.
     * @param amount Amount to transfer.
     */
    function transferFromTeam(address to, uint256 amount) external {
        require(msg.sender == teamWallet, "Only team wallet can transfer");
        require(
            block.timestamp >= teamTokensUnlockTime,
            "Team tokens are locked"
        );
        _transfer(teamWallet, to, amount);
    }

    /**
     * @notice Sets the staking contract address.
     * @param _stakingContract Address of the staking contract.
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(
            _stakingContract != address(0),
            "Invalid staking contract address"
        );
        stakingContract = _stakingContract;
    }

    /**
     * @notice Mints staking rewards to a recipient.
     * @dev Only callable by the staking contract.
     * @param to Address receiving the rewards.
     * @param amount Amount to mint.
     */
    function mintRewards(
        address to,
        uint256 amount
    ) external onlyStakingContract nonReentrant {
        require(
            totalStakingRewardsMinted + amount <= STAKING_REWARDS_AMOUNT,
            "Exceeds staking rewards allocation"
        );
        _mint(to, amount);
        totalStakingRewardsMinted += amount;
        totalTokensMinted += amount;
        emit StakingRewardMinted(to, amount);
    }

    /**
     * @notice Calculates expected staking rewards.
     * @param amount Amount of tokens staked.
     * @param duration Duration of staking in seconds.
     * @return The expected reward amount.
     */
    function calculateExpectedReward(
        uint256 amount,
        uint256 duration
    ) internal pure returns (uint256) {
        return (amount * 10 * duration) / (365 days * 100);
    }
}
