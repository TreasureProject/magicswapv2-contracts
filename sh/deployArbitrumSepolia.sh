# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/MagicswapV2.s.sol:MagicswapV2Script --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast --verify -vvvv
