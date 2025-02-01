import type { HardhatRuntimeEnvironment } from "hardhat/types";
import type { DeployFunction } from "hardhat-deploy/types";

const DEFAULT_LP_FEE = 30n; // 0.3%
const DEFAULT_PROTOCOL_FEE = 30n; // 0.3%

const CHAIN_PARAMS = {
  // Treasure Topaz
  978658: {
    lpFee: DEFAULT_LP_FEE,
    protocolFee: DEFAULT_PROTOCOL_FEE,
    protocolFeeBeneficiary: "0xa65d67513328445b4a4d2f498624483c2601dda4",
    wethAddress: "0x095ded714d42cbd5fb2e84a0ffbfb140e38dc9e1",
  },
  // Treasure
  61166: {
    lpFee: DEFAULT_LP_FEE,
    protocolFee: DEFAULT_PROTOCOL_FEE,
    protocolFeeBeneficiary: "0xa65d67513328445b4a4d2f498624483c2601dda4",
    wethAddress: "0x263d8f36bb8d0d9526255e205868c26690b04b88",
  },
  // Abstract Testnet
  11124: {
    lpFee: DEFAULT_LP_FEE,
    protocolFee: DEFAULT_PROTOCOL_FEE,
    protocolFeeBeneficiary: "0x5a25839b49eec2d4c173b42668a84f5988599929",
    wethAddress: "0xe642f7d1f07af75ed8198f0b4d68f14244baaab5",
  },
  // Abstract
  2741: {
    lpFee: DEFAULT_LP_FEE,
    protocolFee: DEFAULT_PROTOCOL_FEE,
    protocolFeeBeneficiary: "0x5a25839b49eec2d4c173b42668a84f5988599929",
    wethAddress: "0x3439153eb7af838ad19d56e1571fbd09333c2809",
  },
} as const;

type SupportedChainId = keyof typeof CHAIN_PARAMS;

const isSupportedChainId = (chainId: number): chainId is SupportedChainId =>
  chainId in CHAIN_PARAMS;

const func: DeployFunction = async ({
  deployments: { deploy },
  getNamedAccounts,
  getChainId
}: HardhatRuntimeEnvironment) => {
  const [
    { deployer },
    chainIdStr,
  ] = await Promise.all([
    getNamedAccounts(),
    getChainId(),
  ]);

  const chainId = Number(chainIdStr);  
  if (!isSupportedChainId(chainId)) {
    throw new Error(`No deployment params configured for chain ID ${chainId}`);
  }

  const {
    lpFee,
    protocolFee,
    protocolFeeBeneficiary,
    wethAddress,
  } = CHAIN_PARAMS[chainId];

  const factory = await deploy("UniswapV2Factory", {
    from: deployer,
    args: [protocolFee, lpFee, protocolFeeBeneficiary],
  });
  console.log("UniswapV2Factory deployed to:", factory.address);

  const magicSwapV2Router = await deploy("MagicSwapV2Router", {
    from: deployer,
    args: [factory.address, wethAddress],
  });
  console.log("MagicswapV2Router deployed to:", magicSwapV2Router.address);

  const nftVaultFactory = await deploy("NftVaultFactory", {
    from: deployer,
  });
  console.log("NftVaultFactory deployed to:", nftVaultFactory.address);

  const stakingContract = await deploy("StakingContractMainnet", {
    from: deployer,
  });
  console.log("StakingContractMainnet deployed to:", stakingContract.address);

  const nftVaultManagerContract = await deploy("NftVaultManager", {
    from: deployer,
  });
  console.log("NftVaultManager deployed to:", nftVaultManagerContract.address);
}

export default func;
