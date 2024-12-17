import "hardhat-deploy";
import "@treasure-dev/hardhat-kms";
import "@matterlabs/hardhat-zksync";
import "@matterlabs/hardhat-zksync-verify";
import "@nomicfoundation/hardhat-foundry";
import { HardhatUserConfig, task } from "hardhat/config";
import { getUniswapV2BytecodeHash } from "./scripts/getUniswapV2BytecodeHash";


const devKmsKey = process.env.DEV_KMS_RESOURCE_ID;
const prodKmsKey = process.env.PROD_KMS_RESOURCE_ID;

const config: HardhatUserConfig = {
  defaultNetwork: "zkSyncSepolia",
  networks: {
    zkSyncSepolia: {
      url: process.env.ZKSYNC_SEPOLIA_RPC ?? "",
      ethNetwork: "sepolia",
      zksync: true,
      verifyURL: process.env.ZKSYNC_SEPOLIA_VERIFY ?? "",
      kmsKeyId: devKmsKey,
    },
    treasureTopaz: {
      url: process.env.TREASURE_TOPAZ_RPC ?? "",
      ethNetwork: "sepolia",
      zksync: true,
      verifyURL: process.env.TREASURE_TOPAZ_VERIFY ?? "",
      kmsKeyId: devKmsKey,
    },
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC ?? "",
      ethNetwork: "sepolia",
      zksync: true,
      kmsKeyId: devKmsKey,
    },
    arbitrumOne: {
      url: process.env.ARBITRUM_RPC ?? "",
      ethNetwork: "sepolia",
      zksync: false,
      kmsKeyId: devKmsKey,
    },
    treasureMainnet: {
      url: `${process.env.TREASURE_MAINNET_RPC}`,
      kmsKeyId: prodKmsKey,
      ethNetwork: 'mainnet',
      chainId: 0xeeee,
      live: true,
      saveDeployments: true,
      gasMultiplier: 2,
      verifyURL: 'https://rpc-explorer-verify.treasure.lol/contract_verification',
      zksync: true,
  },
    dockerizedNode: {
      url: "http://localhost:3050",
      ethNetwork: "http://localhost:8545",
      zksync: true,
    },
    inMemoryNode: {
      url: "http://127.0.0.1:8011",
      ethNetwork: "localhost", // in-memory node doesn't support eth node; removing this line will cause an error
      zksync: true,
    },
    hardhat: {
      zksync: true,
    },
  },
  zksolc: {
    version: "1.5.7",
    settings: {
      // find all available options in the official documentation
      // https://docs.zksync.io/build/tooling/hardhat/hardhat-zksync-solc#configuration
    },
  },
  solidity: {
    version: "0.8.20",
  },
  namedAccounts: {
    deployer: 0,
  },
};

task(
  "uniswap-bytecode-hash",
  "Prints the bytecode hash of UniswapV2Pair contract",
  async function (taskArguments, hre, runSuper) {
    console.log("uniswapV2 bytecode hash", await getUniswapV2BytecodeHash(hre));
  }
);

export default config;