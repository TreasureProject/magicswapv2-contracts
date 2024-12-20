import type { HardhatRuntimeEnvironment } from 'hardhat/types';
import type { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const protocolFee = 30n; // 0.3%
  const lpFee = 30n; // 0.3%
  const protocolFeeBeneficiary = "0xA65d67513328445B4A4D2F498624483c2601ddA4"; // L2 Treasury

  const uniswapFactoryConstructorArguments = [protocolFee, lpFee, protocolFeeBeneficiary];
  const factory = await deploy('UniswapV2Factory', {
    from: deployer,
    args: uniswapFactoryConstructorArguments,
  });

  console.log("UniswapV2Factory deployed to:", factory.address);

  const wMagic = "0x263D8f36Bb8d0d9526255E205868C26690b04B88";
  const routerConstructorArguments = [factory.address, wMagic];
  const magicSwapV2Router = await deploy('MagicSwapV2Router', {
    from: deployer,
    args: routerConstructorArguments,
  });

  console.log("MagicSwapV2Router  deployed to:", magicSwapV2Router.address);

  const nftVaultFactory = await deploy('NftVaultFactory', {
    from: deployer,
  });

  console.log("NftVaultFactory deployed to:", nftVaultFactory.address);

  const stakingContract = await deploy('StakingContractMainnet', {
    from: deployer,
  });

  console.log("StakingContractMainnet deployed to:", stakingContract.address);
}

export default func;
