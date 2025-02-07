// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {X1Coin} from "../../src/X1Coin.sol";

contract X1CoinTest is Test {
    X1Coin public x1coin;

    address public owner;
    address public teamWallet;
    address public communityWallet;

    /**
     * @dev Set up function runs before each test case.
     * It initializes the contract instance and sets up initial wallet addresses.
     */
    function setUp() public {
        owner = address(this);
        teamWallet = address(0x1);
        communityWallet = address(0x2);

        vm.startPrank(owner);
        x1coin = new X1Coin();

        x1coin.setTeamWallet(teamWallet); // Assign team wallet

        vm.stopPrank();
        x1coin.setCommunityWallet(communityWallet);
    }

    /**
     * @dev Tests whether token details are correctly initialized.
     */
    function testInitialSupplyAndTokenDetails() public view {
        assertEq(x1coin.name(), "X1Coin"); // Check token name
        assertEq(x1coin.symbol(), "X1C"); // Check token symbol
        assertEq(x1coin.totalSupply(), uint256(0), "Initial total supply should be 0");
    }

    /**
     * @dev Tests token distribution among the owner, team, and community wallets.
     */
    function testTokenDistribution() public {
        vm.prank(owner);
        x1coin.distributeTokens(); // Distribute tokens

        // Retrieve expected token distribution amounts
        uint256 publicSaleAmount = x1coin.PUBLIC_SALE_AMOUNT();
        uint256 teamAmount = x1coin.TEAM_ADVISORS_AMOUNT();
        uint256 communityAmount = x1coin.COMMUNITY_DEVELOPMENT_AMOUNT();

        // Validate balances after distribution
        assertEq(x1coin.balanceOf(owner), publicSaleAmount, "Owner should receive public sale tokens");
        assertEq(x1coin.balanceOf(teamWallet), teamAmount, "Team wallet should receive team tokens");
        assertEq(
            x1coin.balanceOf(communityWallet), communityAmount, "Community wallet should receive development tokens"
        );
    }

    /**
     * @dev Tests prevention of multiple distributions.
     */
    function testPreventDoubleDistribution() public {
        vm.prank(owner);
        x1coin.distributeTokens();
        uint256 deployerBalance = x1coin.balanceOf(owner);
        assertTrue(deployerBalance > 0, "Tokens should be distributed first");

        vm.prank(owner);
        vm.expectRevert("Tokens already distributed"); // Expect an error if distributing again
        x1coin.distributeTokens();
    }

    /**
     * @dev Ensures setting wallet addresses to zero is prevented.
     */
    function testSetWalletsWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid team wallet address");
        x1coin.setTeamWallet(address(0));

        vm.prank(owner);
        vm.expectRevert("Invalid community wallet address");
        x1coin.setCommunityWallet(address(0));
    }

    /**
     * @dev Tests that team tokens are locked for a period.
     */
    function testTeamLock() public {
        vm.prank(owner);
        x1coin.distributeTokens();

        vm.prank(teamWallet);
        vm.expectRevert("Team tokens are locked");
        x1coin.transferFromTeam(address(0x3), 1000);

        // Fast forward 6 months (180 days)
        vm.warp(block.timestamp + 180 days);

        vm.prank(teamWallet);
        x1coin.transferFromTeam(address(0x3), 1000);
        assertEq(x1coin.balanceOf(address(0x3)), 1000, "Transfer should succeed after lock period");
    }

    /**
     * @dev Ensures that team cannot transfer tokens before the lock period ends.
     */
    function testTeamTokenTransferBeforeLockPeriod() public {
        vm.prank(owner);
        x1coin.distributeTokens();

        address randomUser = address(0x4);
        vm.prank(teamWallet);
        vm.expectRevert("Team tokens are locked");
        x1coin.transferFromTeam(randomUser, 100);
    }

    /**
     * @dev Ensures team can transfer tokens after lock period ends.
     */
    function testTeamTokenTransferAfterLockPeriod() public {
        vm.prank(owner);
        x1coin.distributeTokens();
        address randomUser = address(0x5);

        // Simulate time passing (181 days, beyond the lock period)
        vm.warp(block.timestamp + 181 days);

        uint256 transferAmount = 500 * 10 ** 18;
        vm.prank(teamWallet);
        x1coin.transferFromTeam(randomUser, transferAmount);

        assertEq(x1coin.balanceOf(randomUser), transferAmount, "Transfer should succeed after lock period");
    }

    /**
     * @dev Ensures only the team wallet can transfer team tokens.
     */
    function testOnlyTeamWalletCanTransfer() public {
        vm.prank(owner);
        x1coin.distributeTokens();
        address randomUser = address(0x6);

        vm.warp(block.timestamp + 181 days);

        vm.prank(randomUser);
        vm.expectRevert("Only team wallet can transfer");
        x1coin.transferFromTeam(randomUser, 100);
    }

    /**
     * @dev Tests setting the staking contract address.
     */
    function testSetStakingContract() public {
        address stakingContract = makeAddr("stakingContract");

        vm.prank(owner);
        x1coin.setStakingContract(stakingContract);

        assertEq(x1coin.stakingContract(), stakingContract, "Staking contract should be set correctly");
    }

    /**
     * @dev Ensures only the staking contract can mint reward tokens.
     */
    function testOnlyStakingContractCanMintRewards() public {
        address stakingContract = makeAddr("stakingContract");
        address randomUser = address(0x7);

        vm.prank(owner);
        x1coin.setStakingContract(stakingContract);

        // Success case: staking contract should be able to mint rewards
        vm.prank(stakingContract);
        x1coin.mintRewards(randomUser, 1000);

        // Failure case: a random user should not be able to mint rewards
        vm.prank(randomUser);
        vm.expectRevert("Only staking contract can mint rewards");
        x1coin.mintRewards(randomUser, 1000);
    }
}
