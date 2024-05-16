import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import './hardhat-extra'

// KMS signer used for production deployments: 0x39c6bf2f2360e993a5ed8e1a30edc01001af64f3
const prodKmsKey = "arn:aws:kms:us-east-1:884078395586:key/mrk-58392046945f4fd3a273d6fee98cf9c8";

// KMS signer used for dev deployments: 0x80b756c9ce65d5a2c2922d4cf778cd2fb2e6fa24
const devKmsKey = "arn:aws:kms:us-west-2:665230337498:key/mrk-a9779aa79c2646429ded5dc3431054ba";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC_URL,
      kmsKeyId: devKmsKey,
      chainId: 421614,
      live: false,
      saveDeployments: true,
      gasMultiplier: 2,
      verify: {
        etherscan: {
          apiUrl: 'https://api-sepolia.arbiscan.io',
          apiKey: process.env.ARBISCAN_API_KEY
        }
      }
    }
  }
}
