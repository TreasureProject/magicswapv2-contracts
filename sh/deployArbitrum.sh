# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/MagicswapV2.s.sol:MagicswapV2Script --aws --rpc-url $ARBITRUM_RPC --broadcast --verify -vvvv
