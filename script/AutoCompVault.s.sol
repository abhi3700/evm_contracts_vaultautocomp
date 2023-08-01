// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {AutoCompVault} from "../src/AutoCompVault.sol";
import {DepositToken} from "../src/DepositToken.sol";

contract AutoCompVaultScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        DepositToken token = new DepositToken("CRV:stETH Token", "CRVstETH", 1_000_0001e18);
        AutoCompVault acvault = new AutoCompVault(address(token), 100, 1 days);
        vm.stopBroadcast();
    }
}
