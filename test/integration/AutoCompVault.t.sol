// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol"; // TODO: for debugging, not production
import {AutoCompVault} from "src/AutoCompVault.sol";
import "src/DepositToken.sol";
import "src/interfaces/IDepositToken.sol";

/// @dev Test Contract for AutoCompVault
contract AutoCompVaultTest is Test {
    // contracts
    AutoCompVault public acvault;
    DepositToken public token; // deposit token

    // constants
    address public constant ZERO_ADDRESS = address(0);
    uint32 public constant ZERO_AMOUNT = 0;
    uint32 public constant ONE_DAY = 86400; // in seconds
    uint32 public constant ONE_WEEK = 604800; // in seconds
    uint32 public constant ONE_MONTH = 2592000; // in seconds
    uint32 public constant ONE_YEAR = 31536000; // in seconds

    // addresses
    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    address public dave;
    address public eve;
    address public isaac;

    function setUp() public {
        // set addresses
        owner = address(this);
        alice = address(1);
        bob = address(2);
        charlie = address(3);
        dave = address(4);
        eve = address(5);
        isaac = address(6);

        // deploy token SC
        token = new DepositToken("CRV:stETH Token", "CRVstETH", 1_000_0001e18);

        // mint 100 tokens to alice, bob, charlie, dave, eve
        token.mint(alice, 100e18);
        token.mint(bob, 100e18);
        token.mint(charlie, 100e18);
        token.mint(dave, 100e18);
        token.mint(eve, 100e18);

        // assert balances
        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.balanceOf(bob), 100e18);
        assertEq(token.balanceOf(charlie), 100e18);
        assertEq(token.balanceOf(dave), 100e18);
        assertEq(token.balanceOf(eve), 100e18);

        //-----------------

        // deploy acvault SC
        // yield percentage set to 0.1% per day i.e. 0.001 => fed as 100
        // yield duration set to 1 day i.e. 86400 seconds
        acvault = new AutoCompVault(address(token), 100, ONE_DAY);
    }

    //###############AutoCompVault###############

    //===Setters===

    // ----deposit----

    function testDepositTwice() public {
        uint256 sharesBefore = acvault.sharesOf(alice);
        vm.startPrank(alice);

        token.approve(address(acvault), 1e18);
        acvault.deposit(IDepositToken(address(token)), 1e18); // 1st deposit
        console.log("amount deposited after 1st deposit: ", acvault.totalDeposited());
        console.log("shares received after 1st deposit: ", acvault.sharesOf(alice));

        console.log("========");
        // set timestamp to 2 months later
        vm.warp(block.timestamp + 12 * ONE_MONTH);

        token.approve(address(acvault), 25e18);
        acvault.deposit(IDepositToken(address(token)), 25e18); // 2nd deposit

        vm.stopPrank();

        console.log("amount deposited after 2nd deposit: ", acvault.totalDeposited());
        console.log("shares received after 2nd deposit: ", acvault.sharesOf(alice));

        uint256 sharesAfter = acvault.sharesOf(alice);
        assertTrue(sharesAfter > sharesBefore); // after 2 deposits
    }

    function testDepositThrice() public {
        // uint256 sharesBefore = acvault.sharesOf(alice);
        vm.startPrank(alice);

        token.approve(address(acvault), 1e18);
        acvault.deposit(IDepositToken(address(token)), 1e18); // 1st deposit
        console.log("alice's deposited amount after 1st deposit: ", acvault.depositedOf(alice));
        console.log("total amount deposited after 1st deposit: ", acvault.totalDeposited());
        console.log("alice's received shares after 1st deposit: ", acvault.sharesOf(alice));
        console.log("total received shares after 1st deposit: ", acvault.totalShares());

        console.log("========");
        // set timestamp to 2 months later
        vm.warp(block.timestamp + 2 * ONE_MONTH);

        token.approve(address(acvault), 15e18);
        acvault.deposit(IDepositToken(address(token)), 15e18); // 2nd deposit
        console.log("alice's deposited amount after 2nd deposit: ", acvault.depositedOf(alice));
        console.log("total amount deposited after 2nd deposit: ", acvault.totalDeposited());
        console.log("alice's received shares after 2nd deposit: ", acvault.sharesOf(alice));
        console.log("total received shares after 2nd deposit: ", acvault.totalShares());

        // uint256 sharesAfter = acvault.sharesOf(alice);
        // assertTrue(sharesAfter > sharesBefore); // after 2 deposits

        console.log("========");
        // set timestamp to 4 months later
        vm.warp(block.timestamp + 4 * ONE_MONTH);

        token.approve(address(acvault), 20e18);
        acvault.deposit(IDepositToken(address(token)), 20e18); // 2nd deposit
        console.log("alice's deposited amount after 3rd deposit: ", acvault.depositedOf(alice));
        console.log("total amount deposited after 3rd deposit: ", acvault.totalDeposited());
        console.log("alice's received shares after 3rd deposit: ", acvault.sharesOf(alice));
        console.log("total received shares after 3rd deposit: ", acvault.totalShares());

        vm.stopPrank();

        // uint256 sharesAfter = acvault.sharesOf(alice);
        // assertTrue(sharesAfter > sharesBefore); // after 2 deposits
    }

    function testDepositFour() public {
        // uint256 sharesBefore = acvault.sharesOf(alice);
        vm.startPrank(alice);

        token.approve(address(acvault), 1e18);
        acvault.deposit(IDepositToken(address(token)), 1e18); // 1st deposit
        console.log("alice's deposited amount after 1st deposit: ", acvault.depositedOf(alice));
        console.log("total amount deposited after 1st deposit: ", acvault.totalDeposited());
        console.log("alice's received shares after 1st deposit: ", acvault.sharesOf(alice));
        console.log("total received shares after 1st deposit: ", acvault.totalShares());

        console.log("========");
        // set timestamp to 2 months later
        vm.warp(block.timestamp + 2 * ONE_MONTH);

        token.approve(address(acvault), 15e18);
        acvault.deposit(IDepositToken(address(token)), 15e18); // 2nd deposit
        console.log("alice's deposited amount after 2nd deposit: ", acvault.depositedOf(alice));
        console.log("total amount deposited after 2nd deposit: ", acvault.totalDeposited());
        console.log("alice's received shares after 2nd deposit: ", acvault.sharesOf(alice));
        console.log("total received shares after 2nd deposit: ", acvault.totalShares());

        // uint256 sharesAfter = acvault.sharesOf(alice);
        // assertTrue(sharesAfter > sharesBefore); // after 2 deposits

        console.log("========");
        // set timestamp to 3 months later
        vm.warp(block.timestamp + 3 * ONE_MONTH);

        token.approve(address(acvault), 20e18);
        acvault.deposit(IDepositToken(address(token)), 20e18); // 2nd deposit
        console.log("alice's deposited amount after 3rd deposit: ", acvault.depositedOf(alice));
        console.log("total amount deposited after 3rd deposit: ", acvault.totalDeposited());
        console.log("alice's received shares after 3rd deposit: ", acvault.sharesOf(alice));
        console.log("total received shares after 3rd deposit: ", acvault.totalShares());

        console.log("========");
        // set timestamp to 4 months later
        vm.warp(block.timestamp + 4 * ONE_MONTH);

        token.approve(address(acvault), 25e18);
        acvault.deposit(IDepositToken(address(token)), 25e18); // 2nd deposit
        console.log("alice's deposited amount after 4th deposit: ", acvault.depositedOf(alice));
        console.log("total amount deposited after 4th deposit: ", acvault.totalDeposited());
        console.log("alice's received shares after 4th deposit: ", acvault.sharesOf(alice));
        console.log("total received shares after 4th deposit: ", acvault.totalShares());

        vm.stopPrank();

        // uint256 sharesAfter = acvault.sharesOf(alice);
        // assertTrue(sharesAfter > sharesBefore); // after 2 deposits
    }

    // ----withdraw----
}
