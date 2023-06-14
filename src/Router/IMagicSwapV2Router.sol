// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../UniswapV2/periphery/interfaces/IUniswapV2Router01.sol";
import "../Vault/INftVault.sol";

/// @title Router contract for swapping, managing liquidity and interacting with vaults
interface IMagicSwapV2Router is IUniswapV2Router01 {
    /// @dev Amounts does not match
    error WrongAmounts();

    /// @notice Struct that specifies data for liquidity-related operations on vault.
    /// @param token address of NFT vault
    /// @param collection list of NFT addresses
    /// @param tokenId list of token IDs
    /// @param amount list of token amounts. For ERC721 amount is always 1.
    struct NftVaultLiquidityData {
        INftVault token;
        address[] collection;
        uint256[] tokenId;
        uint256[] amount;
    }

    /// @notice Emitted on adding liquidity
    /// @param to address that gets LP tokens
    /// @param pair address of the pair where liquidity was added
    /// @param lpAmount amount of LP tokens minted and sent to address
    /// @param vaultA vault data for first side of deposit
    /// @param amountA amount of `tokenA` deposited
    /// @param tokenB address of token for second side of deposit
    /// @param amountB amount of `tokenB` deposited
    event LiquidityAddedNFT(
        address indexed to,
        address pair,
        uint256 lpAmount,
        NftVaultLiquidityData vaultA,
        uint256 amountA,
        address tokenB,
        uint256 amountB
    );

    /// @notice Emitted on removing liquidity
    /// @param to address that gets withdrawn assets
    /// @param pair address of the pair where liquidity was removed
    /// @param lpAmount amount of LP tokens withdrawn from the pool and burned
    /// @param tokenA address of token for first side of deposit
    /// @param amountA amount of `tokenA` deposited
    /// @param collectionsA NFT addresses for first side of deposit
    /// @param tokenIdsA token ids for first side of deposit
    /// @param tokenB address of token for second side of deposit
    /// @param amountB amount of `tokenB` deposited
    /// @param collectionsB NFT addresses for second side of deposit
    /// @param tokenIdsB token ids for second side of deposit
    /// @param swappedLeftover true if leftover tokens were swapped to token B
    event LiquidityRemoved(
        address indexed to,
        address pair,
        uint256 lpAmount,
        address tokenA,
        uint256 amountA,
        address[] collectionsA,
        uint256[] tokenIdsA,
        uint256[] amountsA,
        address tokenB,
        uint256 amountB,
        address[] collectionsB,
        uint256[] tokenIdsB,
        uint256[] amountsB,
        bool swappedLeftover
    );

    /// @notice Deposit NFTs to vault
    /// @dev All NFTs must be approved for transfer. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _collection list of NFT addresses to deposit
    /// @param _tokenId list of token IDs to deposit
    /// @param _amount list of token amounts to deposit. For ERC721 amount is always 1.
    /// @param _vault address of the vault where NFTs are deposited
    /// @param _to address that gets ERC20 for deposited NFTs
    /// @return amountMinted amount of ERC20 minted for deposited NFTs
    function depositVault(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _vault,
        address _to
    ) external returns (uint256 amountMinted);

    /// @dev Withdraw NFTs from vault
    /// @dev Vault token must be approved for transfer. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _collection list of NFT addresses to withdraw
    /// @param _tokenId list of token IDs to withdraw
    /// @param _amount list of token amounts to withdraw. For ERC721 amount is always 1.
    /// @param _vault address of the vault to withdraw NFTs from
    /// @param _to address that gets withdrawn NFTs
    /// @return amountBurned amount of ERC20 redeemed for NFTs
    function withdrawVault(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _vault,
        address _to
    ) external returns (uint256 amountBurned);

    /// @notice Add liquidity to UniV2 pool using NFTs and second ERC20 token
    /// @dev All NFTs and ERC20 token must be approved for transfer. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _vaultA address of token A. TokenA is always a vault.
    /// @param _tokenB address of token B
    /// @param _amountBDesired desired amount of token B to be added as liquidity
    /// @param _amountBMin minimum amount of token B to be added as liquidity
    /// @param _to address that gets LP tokens
    /// @param _deadline transaction deadline
    /// @return amountA amount of token A added as liquidity
    /// @return amountB amount of token B added as liquidity
    /// @return lpAmount amount of LP token minted and sent to `_to`
    function addLiquidityNFT(
        NftVaultLiquidityData memory _vaultA,
        address _tokenB,
        uint256 _amountBDesired,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 lpAmount);

    /// @notice Add liquidity to UniV2 pool using NFTs and ETH
    /// @dev All NFTs token must be approved for transfer. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _collection list of NFT addresses to deposit as liquidity
    /// @param _tokenId list of token IDs to deposit as liquidity
    /// @param _amount list of token amounts to deposit as liquidity. For ERC721 amount is always 1.
    /// @param _token address of vault token. It's the same as "Token A".
    /// @param _amountETHMin desired amount of ETH to be added as liquidity
    /// @param _to address that gets LP tokens
    /// @param _deadline transaction deadline
    /// @return amountToken amount of vault token added as liquidity
    /// @return amountETH amount of ETH added as liquidity
    /// @return lpAmount amount of LP token minted and sent to `_to`
    function addLiquidityNFTETH(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _token,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 lpAmount);

    /// @notice Add liquidity to UniV2 pool using two NFT vaults
    /// @dev All NFTs must be approved for transfer. `_collectionA`, `_tokenIdA`
    ///      and `_amountA` must be of the same length. `_collectionB`,
    ///      `_tokenIdB` and `_amountB` must be of the same length.
    /// @param _collectionA list of NFT addresses to deposit as liquidity for first side
    /// @param _tokenIdA list of token IDs to deposit as liquidity for first side
    /// @param _amountA list of token amounts to deposit as liquidity for first side. For ERC721 amount is always 1.
    /// @param _tokenA address of token A. TokenA is always a vault.
    /// @param _collectionB list of NFT addresses to deposit as liquidity for second side
    /// @param _tokenIdB list of token IDs to deposit as liquidity for second side
    /// @param _amountB list of token amounts to deposit as liquidity for second side. For ERC721 amount is always 1.
    /// @param _tokenB address of token B. TokenB is always a vault.
    /// @param _to address that gets LP tokens
    /// @param _deadline transaction deadline
    /// @return amountA amount of token A added as liquidity
    /// @return amountB amount of token B added as liquidity
    /// @return lpAmount amount of LP token minted and sent to `_to`
    function addLiquidityNFTNFT(
        address[] memory _collectionA,
        uint256[] memory _tokenIdA,
        uint256[] memory _amountA,
        INftVault _tokenA,
        address[] memory _collectionB,
        uint256[] memory _tokenIdB,
        uint256[] memory _amountB,
        INftVault _tokenB,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 lpAmount);

    /// @notice Remove liquidity from UniV2 pool and get NFTs and ERC20 token
    /// @dev Lp token must be approved for transfer. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _collection list of NFT addresses to withdraw
    /// @param _tokenId list of token IDs to withdraw
    /// @param _amount list of token amounts to withdraw. For ERC721 amount is always 1.
    /// @param _tokenA address of token A. TokenA is always a vault.
    /// @param _tokenB address of token B
    /// @param _lpAmount amount of LP token to redeem
    /// @param _amountAMin minimum amount of token A to be redeemed
    /// @param _amountBMin minimum amount of token B to be redeemed
    /// @param _to address that gets LP tokens
    /// @param _deadline transaction deadline
    /// @param _swapLeftover if true, fraction of vault token will be swaped to Token B
    /// @return amountA amount of token A redeemed
    /// @return amountB amount of token B redeemed
    function removeLiquidityNFT(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _tokenA,
        address _tokenB,
        uint256 _lpAmount,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline,
        bool _swapLeftover
    ) external returns (uint256 amountA, uint256 amountB);

    /// @notice Remove liquidity from UniV2 pool and get NFTs and ETH
    /// @dev Lp token must be approved for transfer. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _collection list of NFT addresses to withdraw
    /// @param _tokenId list of token IDs to withdraw
    /// @param _amount list of token amounts to withdraw. For ERC721 amount is always 1.
    /// @param _token address of vault token. It's the same as "Token A".
    /// @param _lpAmount amount of LP token to redeem
    /// @param _amountTokenMin minimum amount of vault token to be redeemed
    /// @param _amountETHMin minimum amount of ETH to be redeemed
    /// @param _to address that gets LP tokens
    /// @param _deadline transaction deadline
    /// @param _swapLeftover if true, fraction of vault token will be swaped to ETH
    /// @return amountToken amount of vault token redeemed
    /// @return amountETH amount of ETH redeemed
    function removeLiquidityNFTETH(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _token,
        uint256 _lpAmount,
        uint256 _amountTokenMin,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline,
        bool _swapLeftover
    ) external returns (uint256 amountToken, uint256 amountETH);

    /// @notice Remove liquidity from UniV2 pool and get NFTs
    /// @dev Lp token must be approved for transfer. `_collectionA`, `_tokenIdA`
    ///      and `_amountA` must be of the same length. `_collectionB`,
    ///      `_tokenIdB` and `_amountB` must be of the same length.
    /// @param _vaultA vault data for first side
    /// @param _vaultB vault data for second side
    /// @param _lpAmount amount of LP token to redeem
    /// @param _amountAMin minimum amount of token A to be redeemed
    /// @param _amountBMin minimum amount of token B to be redeemed
    /// @param _to address that gets LP tokens
    /// @param _deadline transaction deadline
    /// @return amountA amount of token A redeemed
    /// @return amountB amount of token B redeemed
    function removeLiquidityNFTNFT(
        NftVaultLiquidityData memory _vaultA,
        NftVaultLiquidityData memory _vaultB,
        uint256 _lpAmount,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /// @notice Swap NFTs for ERC20
    /// @dev All NFTs must be approved for transfer. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _collection list of NFT addresses to swap for token
    /// @param _tokenId list of token IDs to swap for token
    /// @param _amount list of token amounts to swap for token. For ERC721 amount is always 1.
    /// @param _amountOutMin minimum amount of output token expected after swap
    /// @param _path list of token addresses to swap over
    /// @param _to address that gets output token
    /// @param _deadline transaction deadline
    /// @return amounts input and output amounts of swaps
    function swapNftForTokens(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap NFTs for ETH
    /// @dev All NFTs must be approved for transfer. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _collection list of NFT addresses to swap for ETH
    /// @param _tokenId list of token IDs to swap for ETH
    /// @param _amount list of token amounts to swap for ETH. For ERC721 amount is always 1.
    /// @param _amountOutMin minimum amount of ETH expected after swap
    /// @param _path list of token addresses to swap over
    /// @param _to address that gets ETH
    /// @param _deadline transaction deadline
    /// @return amounts input and output amounts of swaps
    function swapNftForETH(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256[] memory amounts);

    /// @notice Swap ERC20 for NFTs
    /// @dev ERC20 must be approved for transfer. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _collection list of NFT addresses to receive for tokens
    /// @param _tokenId list of token IDs to receive for tokens
    /// @param _amount list of token amounts to receive for tokens. For ERC721 amount is always 1.
    /// @param _amountInMax maximum acceptable amount of token to swap for NFTs
    /// @param _path list of token addresses to swap over
    /// @param _to address that gets NFTs
    /// @param _deadline transaction deadline
    /// @return amounts input and output amounts of swaps
    function swapTokensForNft(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        uint256 _amountInMax,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap ETH for NFTs
    /// @dev Does not require any approvals. `_collection`, `_tokenId`
    ///      and `_amount` must be of the same length.
    /// @param _collection list of NFT addresses to receive for ETH
    /// @param _tokenId list of token IDs to receive for ETH
    /// @param _amount list of token amounts to receive for ETH. For ERC721 amount is always 1.
    /// @param _path list of token addresses to swap over
    /// @param _to address that gets NFTs
    /// @param _deadline transaction deadline
    /// @return amounts input and output amounts of swaps
    function swapETHForNft(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256[] memory amounts);

    /// @notice Swap NFTs for NFTs
    /// @dev All input NFTs must be approved for transfer. It is most likely that input NFTs create a leftover
    ///      during the swap. That leftover is returend to the pool as LP rewards. `_collectionIn`, `_tokenIdIn` and `_amountIn`
    ///      as well as `_collectionOut`, `_tokenIdOut` and `_amountOut` must be of the same length.
    /// @param _collectionIn list of input NFT addresses
    /// @param _tokenIdIn list of input token IDs
    /// @param _amountIn list of input token amounts. For ERC721 amount is always 1.
    /// @param _collectionOut list of output NFT addresses
    /// @param _tokenIdOut list of output token IDs
    /// @param _amountOut list of output token amounts. For ERC721 amount is always 1.
    /// @param _path list of token addresses to swap over
    /// @param _to address that gets NFTs
    /// @param _deadline transaction deadline
    /// @return amounts input and output amounts of swaps
    function swapNftForNft(
        address[] memory _collectionIn,
        uint256[] memory _tokenIdIn,
        uint256[] memory _amountIn,
        address[] memory _collectionOut,
        uint256[] memory _tokenIdOut,
        uint256[] memory _amountOut,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swaps ERC20 for ERC20
    /// @dev Utility function for _swapExactTokensForTokens
    /// @param _tokenA address of token to swap from
    /// @param _tokenB address of token to swap to
    /// @param _amountIn input amount of `_tokenA`
    /// @return amountOut output amount of swapped `_tokenB`
    function swapLeftover(address _tokenA, address _tokenB, uint256 _amountIn) external returns (uint256 amountOut);

    /// @notice Transition number of NFTs into amount of ERC20
    function nftAmountToERC20(uint256[] memory _amount) external pure returns (uint256 amount);
}
