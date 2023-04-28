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

    //###############Ownable###############
    function testGetOwner() public {
        assertEq(acvault.owner(), owner);
    }

    function testTransferOwnership() public {
        acvault.transferOwnership(alice);
        assertEq(acvault.owner(), alice);
    }

    function testRevertTransferOwnershipByNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        acvault.transferOwnership(bob);
    }

    // [OPTIONAL]
    function testTransferOwnershipToSelf() public {
        acvault.transferOwnership(owner);
    }

    function testRevertTransferOwnershipToZeroAddress() public {
        vm.expectRevert("Ownable: new owner is the zero address");
        acvault.transferOwnership(ZERO_ADDRESS);
    }

    function testRenounceOwnership() public {
        acvault.renounceOwnership();
        assertEq(acvault.owner(), ZERO_ADDRESS);
    }
    //###############Pausable###############

    function testGetPauseStatus() public {
        assertEq(acvault.paused(), false);
    }

    function testPauseWhenNotPaused() public {
        acvault.pause();
        assertEq(acvault.paused(), true);
    }

    function testRevertPauseWhenPaused() public {
        acvault.pause();
        vm.expectRevert("Pausable: paused");
        acvault.pause();
    }

    function testUnpauseWhenNotPaused() public {
        vm.expectRevert("Pausable: not paused");
        acvault.unpause();
    }

    function testUnpauseWhenPaused() public {
        acvault.pause();
        acvault.unpause();
        assertEq(acvault.paused(), false);
    }

    function testRevertWhenPausedByNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        acvault.pause();
    }

    function testRevertWhenUnpausedByNonOwner() public {
        acvault.pause();
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        acvault.unpause();
    }

    //###############AutoCompVault###############

    //===Getters===
    function testGetYieldPercentage() public {
        assertEq(acvault.yieldPercentage(), 100);
    }

    function testGetYieldDuration() public {
        assertEq(acvault.yieldDuration(), ONE_DAY);
    }

    function testGetDepositToken() public {
        assertEq(address(acvault.depositToken()), address(token));
    }

    function testGetTotalDeposited() public {
        assertEq(acvault.totalDeposited(), 0);
    }

    function testGetTotalShares() public {
        assertEq(acvault.totalShares(), 0);
    }

    /// @dev test the total shares of a user - 'alice'
    /// for generic case, write fuzz test with random addresses
    function testGetDepositedAmtOf() public {
        assertEq(acvault.sharesOf(alice), 0);
    }

    /// @dev test the total shares of a user - 'alice'
    /// for generic case, write fuzz test with random addresses
    function testGetSharesAmtOf() public {
        assertEq(acvault.sharesOf(alice), 0);
    }

    function testGetLastDepositedTimestamp() public {
        assertEq(acvault.lastDepositedTimestamp(), 0);
    }

    //===Setters===

    // ----deposit----

    function testRevertDepositInvalidToken() public {
        vm.expectRevert(AutoCompVault.InvalidToken.selector);
        acvault.deposit(IDepositToken(address(123)), 100e18);
    }

    function testRevertDepositZeroAmount() public {
        vm.expectRevert(AutoCompVault.ZeroAmount.selector);
        acvault.deposit(IDepositToken(address(token)), 0);
    }

    function testRevertDepositInsufficientBalance() public {
        vm.expectRevert();
        vm.prank(isaac);
        acvault.deposit(IDepositToken(address(token)), 1e18);
    }

    function testRevertDepositWhenPaused() public {
        acvault.pause();
        vm.prank(alice);
        vm.expectRevert();
        acvault.deposit(IDepositToken(address(token)), 1e18);
    }

    function testRevertDepositWhenTokenNotApproved() public {
        vm.prank(alice);
        vm.expectRevert(AutoCompVault.InsufficientDepositAllowance.selector);
        acvault.deposit(IDepositToken(address(token)), 1e18);
    }

    function testDeposit() public {
        uint256 sharesBefore = acvault.sharesOf(alice);
        vm.startPrank(alice);
        token.approve(address(acvault), 1e18);
        acvault.deposit(IDepositToken(address(token)), 1e18);
        assertEq(acvault.totalDeposited(), 1e18);

        uint256 sharesAfter = acvault.sharesOf(alice);
        assertTrue(sharesAfter > sharesBefore);
        assertTrue(sharesAfter == 1e18); // when 1st time deposit
        vm.stopPrank();
    }

    // ----withdraw----
}
