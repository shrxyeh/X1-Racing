
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title X1CoinPublicSale
 * @notice Handles the public sale distribution of X1Coin tokens
 * @dev Implements whitelisting, purchase limits, and vesting schedule
 */
contract X1CoinPublicSale is Ownable, ReentrancyGuard {
    IERC20 public immutable x1coin;

    uint256 public constant PRICE_PER_TOKEN = 0.0001 ether;
    uint256 public constant MIN_PURCHASE = 100 * 10 ** 18; // Minimum purchase of 100 tokens
    uint256 public constant MAX_PURCHASE = 100000 * 10 ** 18; // Maximum purchase of 100,000 tokens

    uint256 public saleStartTime;
    uint256 public saleEndTime;
    uint256 public vestingStartTime;
    uint256 public constant VESTING_DURATION = 180 days;

    mapping(address => bool) public whitelist;
    mapping(address => uint256) public purchases;
    mapping(address => uint256) public claimed;

    bool public saleFinalized;
    uint256 public totalTokensSold;

    event WhitelistUpdated(address indexed user, bool status);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 paid);
    event TokensClaimed(address indexed user, uint256 amount);

    /**
     * @notice Initializes the public sale contract
     * @param _x1coin Address of the X1Coin token contract
     * @param _saleStartTime Timestamp of the sale start time
     * @param _saleDuration Duration of the sale in seconds
     */
    constructor(
        address _x1coin,
        uint256 _saleStartTime,
        uint256 _saleDuration
    ) Ownable(msg.sender) {
        require(_x1coin != address(0), "Invalid token address");
        require(_saleStartTime > block.timestamp, "Invalid start time");

        x1coin = IERC20(_x1coin);
        saleStartTime = _saleStartTime;
        saleEndTime = _saleStartTime + _saleDuration;
    }

    /**
     * @notice Updates the whitelist status for multiple addresses
     * @dev Only the contract owner can call this function
     * @param users Array of addresses to update
     * @param statuses Array of corresponding whitelist statuses (true for whitelisted, false for removed)
     */
    function updateWhitelist(
        address[] calldata users,
        bool[] calldata statuses
    ) external onlyOwner {
        require(users.length == statuses.length, "Array lengths mismatch");
        for (uint256 i = 0; i < users.length; i++) {
            whitelist[users[i]] = statuses[i];
            emit WhitelistUpdated(users[i], statuses[i]);
        }
    }

    /**
     * @notice Allows users to purchase tokens during the sale period
     * @dev Requires the user to be whitelisted and adhere to purchase limits
     */
    function purchaseTokens() external payable nonReentrant {
        require(block.timestamp >= saleStartTime, "Sale not started");
        require(block.timestamp <= saleEndTime, "Sale ended");
        require(whitelist[msg.sender], "Not whitelisted");
        require(!saleFinalized, "Sale finalized");

        uint256 tokenAmount = (msg.value * 10 ** 18) / PRICE_PER_TOKEN;
        require(tokenAmount >= MIN_PURCHASE, "Below minimum purchase");
        require(
            purchases[msg.sender] + tokenAmount <= MAX_PURCHASE,
            "Exceeds max purchase"
        );

        purchases[msg.sender] += tokenAmount;
        totalTokensSold += tokenAmount;

        emit TokensPurchased(msg.sender, tokenAmount, msg.value);
    }

    /**
     * @notice Finalizes the token sale and sets up the vesting schedule
     * @dev Can only be called after the sale period has ended
     */
    function finalizeSale() external onlyOwner {
        require(block.timestamp > saleEndTime, "Sale still active");
        require(!saleFinalized, "Already finalized");

        saleFinalized = true;
        vestingStartTime = block.timestamp;
    }

    /**
     * @notice Allows users to claim their vested tokens
     * @dev Uses a linear vesting schedule over `VESTING_DURATION`
     */
    function claimTokens() external nonReentrant {
        require(saleFinalized, "Sale not finalized");
        require(purchases[msg.sender] > 0, "No tokens purchased");

        uint256 vestedAmount = calculateVestedAmount(msg.sender);
        uint256 claimable = vestedAmount - claimed[msg.sender];
        require(claimable > 0, "No tokens to claim");

        claimed[msg.sender] += claimable;
        require(x1coin.transfer(msg.sender, claimable), "Transfer failed");

        emit TokensClaimed(msg.sender, claimable);
    }

    /**
     * @notice Calculates the amount of vested tokens for a given user
     * @dev Implements a linear vesting model over `VESTING_DURATION`
     * @param user Address of the user
     * @return Amount of tokens vested so far
     */
    function calculateVestedAmount(address user) public view returns (uint256) {
        if (!saleFinalized || block.timestamp < vestingStartTime) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - vestingStartTime;
        if (timeElapsed >= VESTING_DURATION) {
            return purchases[user];
        }

        return (purchases[user] * timeElapsed) / VESTING_DURATION;
    }

    /**
     * @notice Withdraws the collected ETH to the owner's address
     * @dev Can only be called after the sale has been finalized
     */
    function withdrawETH() external onlyOwner {
        require(saleFinalized, "Sale not finalized");
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}
