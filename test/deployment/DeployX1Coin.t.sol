// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployX1Coin} from "../../script/DeployX1Coin.s.sol";
import {X1Coin} from "../../src/X1Coin.sol";
import {X1Staking} from "../../src/X1Staking.sol";

/**
 * @title DeployX1CoinTest
 * @dev Test contract for verifying the deployment of X1Coin and X1Staking contracts
 */
contract DeployX1CoinTest is Test {
    DeployX1Coin public deployer;
    address public owner;
    address public teamWallet;
    address public communityWallet;
    uint256 public privateKey;

    /**
     * @dev Sets up the test environment, initializing the deployer and funding the owner account.
     */
    function setUp() public {
        privateKey = vm.envUint("PRIVATE_KEY");

        vm.roll(1);
        vm.warp(1);

        vm.startPrank(msg.sender);

        deployer = new DeployX1Coin();
        owner = vm.addr(privateKey);
        teamWallet = address(0x1);
        communityWallet = address(0x2);

        vm.resetNonce(owner);
        vm.deal(owner, 100 ether);

        vm.stopPrank();
    }

    /**
     * @dev Sets environment variables used for deployment.
     */
    function _setEnvironmentVariables() internal {
        vm.setEnv("PRIVATE_KEY", vm.toString(privateKey));
        vm.setEnv("TEAM_WALLET", vm.toString(teamWallet));
        vm.setEnv("COMMUNITY_WALLET", vm.toString(communityWallet));
    }

    /**
     * @dev Tests the deployment script execution.
     */
    function testDeploymentScript() public {
        _setEnvironmentVariables();

        assertEq(vm.envUint("PRIVATE_KEY"), privateKey, "PRIVATE_KEY not set correctly");
        assertEq(vm.envAddress("TEAM_WALLET"), teamWallet, "TEAM_WALLET not set correctly");
        assertEq(vm.envAddress("COMMUNITY_WALLET"), communityWallet, "COMMUNITY_WALLET not set correctly");

        try deployer.run() {
            assertTrue(true);
        } catch Error(string memory reason) {
            console.log("Deployment failed:", reason);
            revert(reason);
        }
    }

    /**
     * @dev Tests if the deployment reverts when an invalid team wallet is provided.
     */
    function test_RevertDeploymentWithInvalidTeamWallet() public {
        vm.setEnv("TEAM_WALLET", vm.toString(address(0)));
        vm.expectRevert(DeployX1Coin.InvalidAddress.selector);
        deployer.run();
    }

    /**
     * @dev Tests if the deployment reverts when an invalid community wallet is provided.
     */
    function test_RevertDeploymentWithInvalidCommunityWallet() public {
        vm.setEnv("COMMUNITY_WALLET", vm.toString(address(0)));
        vm.expectRevert(DeployX1Coin.InvalidAddress.selector);
        deployer.run();
    }

    /**
     * @dev Validates the successful deployment of X1Coin and X1Staking contracts.
     */
    function testValidateDeployment() public {
        _setEnvironmentVariables();
        vm.recordLogs();
        deployer.run();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 deploymentTopic = keccak256("DeploymentComplete(address,address,address,address)");
        address x1CoinAddress;
        address stakingAddress;
        bool found = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == deploymentTopic) {
                (x1CoinAddress, stakingAddress,,) = abi.decode(entries[i].data, (address, address, address, address));
                found = true;
                break;
            }
        }

        require(found, "Deployment event not found in logs");
        require(x1CoinAddress != address(0), "X1Coin address is zero");
        require(stakingAddress != address(0), "Staking address is zero");

        bool isValid = deployer.validateDeployment(x1CoinAddress, stakingAddress, teamWallet, communityWallet);
        assertTrue(isValid, "Deployment validation failed");

        X1Coin x1coin = X1Coin(x1CoinAddress);
        X1Staking staking = X1Staking(stakingAddress);

        assertEq(address(staking.x1Token()), x1CoinAddress, "Invalid token address in staking");
        assertEq(x1coin.teamWallet(), teamWallet, "Invalid team wallet");
        assertEq(x1coin.communityWallet(), communityWallet, "Invalid community wallet");
        assertEq(x1coin.stakingContract(), stakingAddress, "Invalid staking contract");
    }

    /**
     * @dev Ensures the correct deployment configuration, including token distribution.
     */
    function testDeploymentConfiguration() public {
        _setEnvironmentVariables();
        vm.recordLogs();
        deployer.run();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 deploymentTopic = keccak256("DeploymentComplete(address,address,address,address)");
        address x1CoinAddress;
        address stakingAddress;
        bool found = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == deploymentTopic) {
                (x1CoinAddress, stakingAddress,,) = abi.decode(entries[i].data, (address, address, address, address));
                found = true;
                break;
            }
        }

        require(found, "Deployment event not found in logs");
        require(x1CoinAddress != address(0), "X1Coin address is zero");
        require(stakingAddress != address(0), "Staking address is zero");

        X1Coin x1coin = X1Coin(x1CoinAddress);
        X1Staking staking = X1Staking(stakingAddress);

        assertEq(x1coin.teamWallet(), teamWallet, "Invalid team wallet");
        assertEq(x1coin.communityWallet(), communityWallet, "Invalid community wallet");
        assertEq(x1coin.stakingContract(), stakingAddress, "Invalid staking contract");
        assertEq(address(staking.x1Token()), x1CoinAddress, "Invalid token address in staking");

        uint256 TOTAL_SUPPLY = x1coin.TOTAL_SUPPLY();
        uint256 publicSaleAmount = (TOTAL_SUPPLY * 50) / 100;
        uint256 teamAmount = (TOTAL_SUPPLY * 30) / 100;
        uint256 communityAmount = (TOTAL_SUPPLY * 20) / 100;

        assertEq(x1coin.balanceOf(owner), publicSaleAmount, "Invalid public sale amount");
        assertEq(x1coin.balanceOf(teamWallet), teamAmount, "Invalid team amount");
        assertEq(x1coin.balanceOf(communityWallet), communityAmount, "Invalid community amount");
    }
}
