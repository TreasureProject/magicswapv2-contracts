# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/MagicswapV2.s.sol:MagicswapV2Script --rpc-url $ARBITRUM_GOERLI_RPC --broadcast --verify -vvvv
