import hre from "hardhat";
import { utils } from "zksync-ethers";
import { hexlify } from "ethers";
export const getUniswapV2BytecodeHash = async () => {
    const artifact = await hre.artifacts.readArtifact("UniswapV2Pair");
    const bytecodeHash = utils.hashBytecode(artifact.bytecode);
    const hexString = hexlify(bytecodeHash);

    console.log("bytecodeHash", hexString);
    
    return bytecodeHash;
}


getUniswapV2BytecodeHash();