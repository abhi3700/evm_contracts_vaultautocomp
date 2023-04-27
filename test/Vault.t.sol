// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol"; // TODO: for debugging, not production
import {Vault} from "src/Vault.sol";
import "src/DepositToken.sol";

contract VaultTest is Test {
    Vault public vault;
    DepositToken public token; // deposit token

    address public constant ZERO_ADDRESS = address(0);

    // addresses
    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    address public dave;
    address public eve;

    function setUp() public {
        // set addresses
        owner = address(this);
        alice = address(1);
        bob = address(2);
        charlie = address(3);
        dave = address(4);
        eve = address(5);

        // deploy token SC
        token = new DepositToken("CRV:stETH Token", "CRVstETH", 1_000_0001e18);

        // deploy vault SC
        // yield set to 0.1% per day i.e. 0.001 => fed as 1e15
        vault = new Vault(address(token), 1e15);
    }

    //###############Ownable###############
    function testGetOwner() public {
        assertEq(vault.owner(), owner);
    }

    function testTransferOwnership() public {
        vault.transferOwnership(alice);
        assertEq(vault.owner(), alice);
    }

    function testRevertTransferOwnershipByNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.transferOwnership(bob);
    }

    // [OPTIONAL]
    function testTransferOwnershipToSelf() public {
        vault.transferOwnership(owner);
    }

    function testRevertTransferOwnershipToZeroAddress() public {
        vm.expectRevert("Ownable: new owner is the zero address");
        vault.transferOwnership(ZERO_ADDRESS);
    }

    function testRenounceOwnership() public {
        vault.renounceOwnership();
        assertEq(vault.owner(), ZERO_ADDRESS);
    }
    //###############Pausable###############

    function testGetPauseStatus() public {
        assertEq(vault.paused(), false);
    }

    function testPauseWhenNotPaused() public {
        vault.pause();
        assertEq(vault.paused(), true);
    }

    function testUnpauseWhenPaused() public {
        vault.pause();
        vault.unpause();
        assertEq(vault.paused(), false);
    }

    function testRevertWhenPausedByNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.pause();
    }

    function testRevertWhenUnpausedByNonOwner() public {
        vault.pause();
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.unpause();
    }

    //###############Vault###############

    //===Getters===
    function testGetYieldInterest() public {
        assertEq(vault.dailyield(), 1e15);
    }

    function testGetDepositToken() public {
        assertEq(address(vault.depositToken()), address(token));
    }

    function testGetReceiptToken() public {
        // M-1: check if receipt token is deployed
        // assertTrue(address(vault.receiptToken()) != ZERO_ADDRESS);

        // M-2: check the code size of the contract
        address _rToken = address(vault.receiptToken());

        uint256 hevmCodeSize = 0;
        assembly {
            hevmCodeSize := extcodesize(_rToken)
        }
        assertTrue(hevmCodeSize > 0);
    }

    function testGetTotalDeposited() public {
        assertEq(vault.totalDeposited(), 0);
    }

    function testGetTotalShares() public {
        assertEq(vault.totalShares(), 0);
    }

    /// @dev test the total shares of a user - 'alice'
    /// for generic case, write fuzz test with random addresses
    function testGetDepositedAmtOf() public {
        assertEq(vault.sharesOf(alice), 0);
    }

    /// @dev test the total shares of a user - 'alice'
    /// for generic case, write fuzz test with random addresses
    function testGetSharesAmtOf() public {
        assertEq(vault.sharesOf(alice), 0);
    }

    //===Setters===

    function testRevertDepositInvalidToken() public {
        vm.expectRevert(Vault.InvalidToken.selector);
        vault.deposit(IERC20(address(123)), 100e18);
    }

    function testRevertDepositZeroAmount() public {
        vm.expectRevert(Vault.ZeroAmount.selector);
        vault.deposit(token, 0);
    }
}
