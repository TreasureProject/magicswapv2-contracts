// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import "forge-std/Script.sol";
import "../contracts/Vault/NftVaultFactory.sol";
import "../contracts/UniswapV2/core/UniswapV2Factory.sol";
import "../contracts/Router/MagicSwapV2Router.sol";

contract MagicswapV2Script is Script {
    function run() public {
        vm.startBroadcast();

        // Set base fees per TIP-40
        address protocolFeeBeneficiary = 0x0eB5B03c0303f2F47cD81d7BE4275AF8Ed347576; // L2 Treasury
        uint256 protocolFee = 30; // 0.3%
        uint256 lpFee = 30; // 0.3%

        // Deploy UniswapV2Factory
        UniswapV2Factory factory = new UniswapV2Factory(protocolFee, lpFee, protocolFeeBeneficiary);

        // Deploy MagicswapV2Router
        address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // TBA: wMAGIC
        new MagicSwapV2Router(address(factory), WETH);

        // Deploy NftVaultFactory
        new NftVaultFactory();

        vm.stopBroadcast();
    }
}
