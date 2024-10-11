import type { HardhatRuntimeEnvironment } from 'hardhat/types';
import type { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const protocolFee = 30n; // 0.3%
  const lpFee = 30n; // 0.3%
  const protocolFeeBeneficiary = "0x0eB5B03c0303f2F47cD81d7BE4275AF8Ed347576"; // L2 Treasury

  const uniswapFactoryConstructorArguments = [protocolFee, lpFee, protocolFeeBeneficiary];
  const factory = await deploy('UniswapV2Factory', {
    from: deployer,
    args: uniswapFactoryConstructorArguments,
  });

  console.log("UniswapV2Factory deployed to:", factory.address);

  const wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
  const routerConstructorArguments = [factory.address, wethAddress];
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
