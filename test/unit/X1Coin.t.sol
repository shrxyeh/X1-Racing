// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {X1Coin} from "../../src/X1Coin.sol";

contract X1CoinTest is Test {
    X1Coin public x1coin;

    address public owner;
    address public teamWallet;
    address public communityWallet;
    address public publicSaleContract;
    address public stakingContract;

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;
    uint256 public constant STAKING_REWARDS_AMOUNT = (TOTAL_SUPPLY * 5) / 100; // 5% of total supply
    uint256 public constant MAX_ANNUAL_REWARDS = (TOTAL_SUPPLY * 1) / 100; // 1% of total supply

    /**
     * @dev Set up function runs before each test case.
     * It initializes the contract instance and sets up initial wallet addresses.
     */
    function setUp() public {
        owner = address(this);
        teamWallet = address(0x1);
        communityWallet = address(0x2);
        publicSaleContract = address(0x3);
        stakingContract = address(0x4);

        vm.startPrank(owner);
        x1coin = new X1Coin(teamWallet, communityWallet, publicSaleContract);
        x1coin.setStakingContract(stakingContract);
        vm.stopPrank();
    }

    function testRewardInflationPrevention() public {
        vm.startPrank(owner);
        x1coin.initialize();
        vm.stopPrank();

        vm.startPrank(stakingContract);

        // Test 1: Initial mint within limits
        uint256 initialMint = STAKING_REWARDS_AMOUNT / 2;
        x1coin.mintRewards(address(0x7), initialMint);
        assertEq(
            x1coin.totalTokensMinted(),
            initialMint,
            "Initial mint should be recorded"
        );

        // Test 2: Try to exceed total staking rewards allocation
        vm.expectRevert("Exceeds staking rewards allocation");
        x1coin.mintRewards(address(0x7), STAKING_REWARDS_AMOUNT + 1);

        // Test 3: Test approaching the cap
        uint256 remainingAllocation = STAKING_REWARDS_AMOUNT - initialMint;
        if (remainingAllocation > 0) {
            x1coin.mintRewards(address(0x8), remainingAllocation - 1);

            // Should fail when trying to mint even 1 more token
            vm.expectRevert("Exceeds staking rewards allocation");
            x1coin.mintRewards(address(0x8), 2);
        }

        vm.stopPrank();
    }

    function testRewardMintingAccessControl() public {
        vm.startPrank(owner);
        x1coin.initialize();
        vm.stopPrank();

        // Test non-staking contract address trying to mint
        address nonStakingContract = address(0x9);
        vm.prank(nonStakingContract);
        vm.expectRevert("Only staking contract can call");
        x1coin.mintRewards(address(0x7), 1000);

        // Test owner cannot mint rewards
        vm.prank(owner);
        vm.expectRevert("Only staking contract can call");
        x1coin.mintRewards(address(0x7), 1000);

        // Test regular user cannot mint rewards
        vm.prank(address(0x10));
        vm.expectRevert("Only staking contract can call");
        x1coin.mintRewards(address(0x7), 1000);

        // Verify staking contract can still mint within limits
        vm.prank(stakingContract);
        x1coin.mintRewards(address(0x7), 1000);
        assertEq(
            x1coin.balanceOf(address(0x7)),
            1000,
            "Staking contract should be able to mint"
        );
    }

    function testAnnualRewardReset() public {
        vm.startPrank(owner);
        x1coin.initialize();
        vm.stopPrank();

        vm.startPrank(stakingContract);

        // Mint some rewards
        uint256 initialMint = MAX_ANNUAL_REWARDS / 2;
        x1coin.mintRewards(address(0x7), initialMint);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        // Should be able to mint up to MAX_ANNUAL_REWARDS again
        x1coin.mintRewards(address(0x8), initialMint);

        // Verify total minted is still tracked correctly
        assertEq(
            x1coin.totalStakingRewardsMinted(),
            initialMint * 2,
            "Total minted should accumulate"
        );

        vm.stopPrank();
    }

    function testRewardMintingPrecision() public {
        vm.startPrank(owner);
        x1coin.initialize();
        vm.stopPrank();

        vm.startPrank(stakingContract);

        // Test minting small amounts
        uint256 smallAmount = 1;
        x1coin.mintRewards(address(0x7), smallAmount);
        assertEq(
            x1coin.balanceOf(address(0x7)),
            smallAmount,
            "Should handle small amounts"
        );

        // Test minting max possible amount
        uint256 remainingRewards = STAKING_REWARDS_AMOUNT - smallAmount;
        x1coin.mintRewards(address(0x7), remainingRewards);
        assertEq(
            x1coin.balanceOf(address(0x7)),
            STAKING_REWARDS_AMOUNT,
            "Should handle max amount"
        );

        vm.stopPrank();
    }

    /**
     * @dev Tests whether token details are correctly initialized.
     */
    function testInitialSupplyAndTokenDetails() public view {
        assertEq(x1coin.name(), "X1Coin");
        assertEq(x1coin.symbol(), "X1C");
        assertEq(x1coin.totalSupply(), uint256(0));
    }

    /**
     * @dev Tests token distribution among the owner, team, and community wallets.
     */
    function testTokenDistribution() public {
        vm.prank(owner);
        x1coin.initialize();

        uint256 publicSaleAmount = x1coin.PUBLIC_SALE_AMOUNT();
        uint256 teamAmount = x1coin.TEAM_ADVISORS_AMOUNT();
        uint256 communityAmount = x1coin.COMMUNITY_DEVELOPMENT_AMOUNT();

        assertEq(
            x1coin.balanceOf(publicSaleContract),
            publicSaleAmount,
            "Public sale contract should receive public sale tokens"
        );
        assertEq(
            x1coin.balanceOf(teamWallet),
            teamAmount,
            "Team wallet should receive team tokens"
        );
        assertEq(
            x1coin.balanceOf(communityWallet),
            communityAmount,
            "Community wallet should receive development tokens"
        );
    }

    /**
     * @dev Tests prevention of multiple distributions.
     */
    function testPreventDoubleDistribution() public {
        vm.startPrank(owner);

        x1coin.initialize();

        uint256 publicSaleBalance = x1coin.balanceOf(publicSaleContract);
        assertTrue(publicSaleBalance > 0, "Tokens should be distributed first");

        vm.expectRevert("Already initialized");
        x1coin.initialize();

        vm.stopPrank();
    }

    /**
     * @dev Ensures setting wallet addresses to zero is prevented.
     */
    function testFailSetWalletsWithZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert("Invalid team wallet address");
        x1coin.setTeamWallet(address(0));

        vm.expectRevert("Invalid community wallet address");
        x1coin.setCommunityWallet(address(0));

        vm.stopPrank();
    }

    /**
     * @dev Tests that team tokens are locked for a period.
     */
    function testTeamLock() public {
        vm.prank(owner);
        x1coin.initialize();

        address targetAddress = address(0x3);
        uint256 initialBalance = x1coin.balanceOf(targetAddress);

        vm.prank(teamWallet);
        vm.expectRevert("Team tokens are locked");
        x1coin.transferFromTeam(targetAddress, 1000);

        vm.warp(block.timestamp + 180 days);

        vm.prank(teamWallet);
        uint256 transferAmount = 1000;
        x1coin.transferFromTeam(targetAddress, transferAmount);

        assertEq(
            x1coin.balanceOf(targetAddress),
            initialBalance + transferAmount,
            "Transfer should increase balance by exact amount"
        );
    }

    /**
     * @dev Ensures that team cannot transfer tokens before the lock period ends.
     */
    function testTeamTokenTransferBeforeLockPeriod() public {
        vm.prank(owner);
        x1coin.initialize();

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
        x1coin.initialize();
        address randomUser = address(0x5);

        vm.warp(block.timestamp + 181 days);

        uint256 transferAmount = 500 * 10 ** 18;
        vm.prank(teamWallet);
        x1coin.transferFromTeam(randomUser, transferAmount);

        assertEq(
            x1coin.balanceOf(randomUser),
            transferAmount,
            "Transfer should succeed after lock period"
        );
    }

    /**
     * @dev Ensures only the team wallet can transfer team tokens.
     */
    function testOnlyTeamWalletCanTransfer() public {
        vm.prank(owner);
        x1coin.initialize();
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
        vm.prank(owner);
        x1coin.setStakingContract(stakingContract);

        assertEq(
            x1coin.stakingContract(),
            stakingContract,
            "Staking contract should be set correctly"
        );
    }

    /**
     * @dev Ensures only the staking contract can mint reward tokens.
     */
    function testOnlyStakingContractCanMintRewards() public {
        vm.prank(owner);
        x1coin.setStakingContract(stakingContract);

        vm.prank(stakingContract);
        x1coin.mintRewards(address(0x7), 1000);

        vm.prank(address(0x7));
        vm.expectRevert("Only staking contract can call");
        x1coin.mintRewards(address(0x7), 1000);
    }
}
