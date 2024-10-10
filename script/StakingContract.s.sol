// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import "forge-std/Script.sol";
import "../src/Rewards/StakingContractMainnet.sol";

contract StakingContractScript is Script {
    function run() public {
        vm.startBroadcast();

        new StakingContractMainnet();

        vm.stopBroadcast();
    }
}
