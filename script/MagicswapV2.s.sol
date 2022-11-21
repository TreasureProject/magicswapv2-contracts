// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import "forge-std/Script.sol";
import "../src/Vault/NftVaultFactory.sol";
import "../src/UniswapV2/core/UniswapV2Factory.sol";
import "../src/Router/MagicSwapV2Router.sol";

contract MagicswapV2Script is Script {
    function run() public {
        // arbitrum WETH
        address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        address protocolFeeBeneficiary = address(1);
        uint256 protocolFee = 0;
        uint256 lpFee = 30;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        UniswapV2Factory factory = new UniswapV2Factory(protocolFee, lpFee, protocolFeeBeneficiary);
        new MagicSwapV2Router(address(factory), WETH);

        new NftVaultFactory();

        vm.stopBroadcast();
    }
}