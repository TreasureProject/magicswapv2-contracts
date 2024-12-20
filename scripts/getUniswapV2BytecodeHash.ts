import { utils } from "zksync-ethers";
import { hexlify } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

export const getUniswapV2BytecodeHash = async (hre: HardhatRuntimeEnvironment) => {
    const artifact = await hre.artifacts.readArtifact("UniswapV2Pair");
    const bytecodeHash = utils.hashBytecode(artifact.bytecode);
    const hexString = hexlify(bytecodeHash);
    
    return hexString;
}