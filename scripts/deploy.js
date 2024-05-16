const { ethers, waffle } = require("hardhat");


async function main() {
    const wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
    const protocolFeeBeneficiary = "0x0000000000000000000000000000000000000001";
    const protocolFee = 0;
    const lpFee = 30;

    const uniContract = await (await ethers.getContractFactory("UniswapV2Factory")).deploy(protocolFee, lpFee, protocolFeeBeneficiary);
    console.log(`Deployed UniswapV2Factory to ${uniContract.target}`);

    const magicSwapV2Router = await (await ethers.getContractFactory("MagicSwapV2Router")).deploy(uniContract.target, wethAddress);
    console.log(`Deployed MagicSwapV2Router to ${magicSwapV2Router.target}`);

    const nftVaultFactory = await (await ethers.getContractFactory("NftVaultFactory")).deploy();
    console.log(`Deployed NftVaultFactory to ${nftVaultFactory.target}`);
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
