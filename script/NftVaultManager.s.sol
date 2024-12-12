// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import "forge-std/Script.sol";
import "../src/Vault/NftVaultManager.sol";

contract NftVaultManagerScript is Script {
    function run() public {
        vm.startBroadcast();

        new NftVaultManager();

        vm.stopBroadcast();
    }
}
