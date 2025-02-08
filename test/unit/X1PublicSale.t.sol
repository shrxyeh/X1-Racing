
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/X1CoinPublicSale.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("X1Coin", "X1") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract X1CoinPublicSaleTest is Test {
    X1CoinPublicSale public sale;
    ERC20Mock public x1coin;
    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);

    uint256 constant PRICE_PER_TOKEN = 0.0001 ether;
    uint256 constant MIN_PURCHASE = 100 ether;
    uint256 constant MAX_PURCHASE = 100_000 ether;
    uint256 saleStartTime;
    uint256 saleDuration = 1000;

    function setUp() public {
        x1coin = new ERC20Mock();

        saleStartTime = block.timestamp + 10;
        sale = new X1CoinPublicSale(
            address(x1coin),
            saleStartTime,
            saleDuration
        );

        x1coin.transfer(address(sale), 1_000_000 ether);
    }

    /// @dev Test contract deployment
    function testDeployment() public view {
        assertEq(address(sale.x1coin()), address(x1coin));
        assertEq(sale.saleStartTime(), saleStartTime);
        assertEq(sale.saleEndTime(), saleStartTime + saleDuration);
    }

    /// @dev Test owner updating whitelist
    function testUpdateWhitelist() public {
        address[] memory users = new address[](2);
        bool[] memory statuses = new bool[](2);

        users[0] = user1;
        users[1] = user2;
        statuses[0] = true;
        statuses[1] = false;

        sale.updateWhitelist(users, statuses);
        assertTrue(sale.whitelist(user1));
        assertFalse(sale.whitelist(user2));
    }

    /// @dev Test non-owner cannot update whitelist
    function test_RevertUpdateWhitelistNonOwner() public {
        vm.prank(user1);
        address[] memory users = new address[](1);
        bool[] memory statuses = new bool[](1);

        users[0] = user1;
        statuses[0] = true;

        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        sale.updateWhitelist(users, statuses);
    }

    /// @dev Test purchasing tokens
    function testPurchaseTokens() public {
        vm.warp(saleStartTime + 1); // Move time to after sale starts
        vm.deal(user1, 1 ether); // Give user1 some ETH

        address[] memory users = new address[](1);
        bool[] memory statuses = new bool[](1);
        users[0] = user1;
        statuses[0] = true;
        sale.updateWhitelist(users, statuses);

        vm.prank(user1);
        sale.purchaseTokens{value: 0.1 ether}();

        assertEq(
            sale.purchases(user1),
            (0.1 ether * 10 ** 18) / PRICE_PER_TOKEN
        );
        assertEq(
            sale.totalTokensSold(),
            (0.1 ether * 10 ** 18) / PRICE_PER_TOKEN
        );
    }

    /// @dev Test purchasing tokens below minimum limit
    function test_RevertPurchaseBelowMin() public {
        vm.warp(saleStartTime + 1);
        vm.deal(user1, 1 ether);

        address[] memory users = new address[](1);
        bool[] memory statuses = new bool[](1);
        users[0] = user1;
        statuses[0] = true;
        sale.updateWhitelist(users, statuses);

        vm.prank(user1);
        vm.expectRevert("Below minimum purchase"); // Add this line to expect the revert
        sale.purchaseTokens{value: 0.0001 ether}(); // Below min purchase
    }

    /// @dev Test purchasing tokens above maximum limit
    function test_RevertPurchaseAboveMax() public {
        vm.warp(saleStartTime + 1);
        vm.deal(user1, 11 ether);

        address[] memory users = new address[](1);
        bool[] memory statuses = new bool[](1);
        users[0] = user1;
        statuses[0] = true;
        sale.updateWhitelist(users, statuses);

        vm.prank(user1);
        vm.expectRevert("Exceeds max purchase"); // Match the exact error message from the contract
        sale.purchaseTokens{value: 10.1 ether}(); // Slightly above max purchase
    }

    /// @dev Test sale finalization
    function testFinalizeSale() public {
        vm.warp(saleStartTime + saleDuration + 1);

        sale.finalizeSale();
        assertTrue(sale.saleFinalized());
        assertEq(sale.vestingStartTime(), block.timestamp);
    }

    /// @dev Test claiming vested tokens
    function testClaimTokens() public {
        vm.warp(saleStartTime + 1);
        vm.deal(user1, 1 ether);

        address[] memory users = new address[](1);
        bool[] memory statuses = new bool[](1);
        users[0] = user1;
        statuses[0] = true;
        sale.updateWhitelist(users, statuses);

        vm.prank(user1);
        sale.purchaseTokens{value: 1 ether}();

        vm.warp(saleStartTime + saleDuration + 1);
        sale.finalizeSale();

        vm.warp(block.timestamp + (sale.VESTING_DURATION() / 2));
        vm.prank(user1);
        sale.claimTokens();

        uint256 expectedClaimable = (sale.purchases(user1) *
            (sale.VESTING_DURATION() / 2)) / sale.VESTING_DURATION();
        assertEq(sale.claimed(user1), expectedClaimable);
    }

    /// @dev Test owner can withdraw ETH
    function testWithdrawETH() public {
        vm.warp(saleStartTime + 1);
        vm.deal(user1, 1 ether);

        address[] memory users = new address[](1);
        bool[] memory statuses = new bool[](1);
        users[0] = user1;
        statuses[0] = true;
        sale.updateWhitelist(users, statuses);

        vm.prank(user1);
        sale.purchaseTokens{value: 1 ether}();

        vm.warp(saleStartTime + saleDuration + 1);
        sale.finalizeSale();

        uint256 balanceBefore = address(this).balance;
        assertEq(address(sale).balance, 1 ether, "Contract balance mismatch");

        sale.withdrawETH();
        uint256 balanceAfter = address(this).balance;

        assertEq(balanceAfter, balanceBefore + 1 ether);
    }

    receive() external payable {
        // Receive ETH
    }
}
