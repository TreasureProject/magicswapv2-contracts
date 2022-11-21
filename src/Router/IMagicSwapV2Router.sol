// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.17;

import "../UniswapV2/periphery/interfaces/IUniswapV2Router02.sol";
import "../Vault/INftVault.sol";

interface IMagicSwapV2Router is IUniswapV2Router02 {
    /// @notice Deposit NFTs to vault
    /// @dev All NFTs must be approved for transfer
    function depositVault(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _vault,
        address _to
    ) external returns (uint256 amountMinted);

    /// @dev Withdraw NFTs from vault
    /// @dev Vault token must be approved for transfer
    function withdrawVault(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _vault,
        address _to
    ) external returns (uint256 amountBurned);

    /// @notice Add liquidity to UniV2 pool using NFTs and second ERC20 token
    /// @dev All NFTs and ERC20 token must be approved for transfer
    function addLiquidityNFT(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _tokenA,
        address _tokenB,
        uint256 _amountBDesired,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 lpAmount);

    /// @notice Add liquidity to UniV2 pool using NFTs and ETH
    /// @dev All NFTs token must be approved for transfer
    function addLiquidityNFTETH(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _token,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 lpAmount);

    /// @notice Remove liquidity from UniV2 pool and get NFTs and ERC20 token
    /// @dev Lp token must be approved for transfer
    /// @dev If `_tokenA` withdrew from UniV2 pool is unequal number, leftover is automatically swapped to `_tokenB`
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
    /// @dev Lp token must be approved for transfer
    /// @dev If `_tokenA` withdrew from UniV2 pool is unequal number, leftover is automatically swapped to ETH
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

    /// @notice Swap NFTs for ERC20
    /// @dev All NFTs must be approved for transfer
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
    /// @dev All NFTs must be approved for transfer
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
    /// @dev ERC20 must be approved for transfer
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
    /// @dev Does not require any approvals
    function swapETHForNft(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256[] memory amounts);

    /// @notice Swap NFTs for NFTs
    /// @dev All input NFTs must be approved for transfer. It is mosy likely that input NFTs create a leftover
    /// during the swap. That leftover is returend to the user.
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

    function swapLeftover(address _tokenA, address _tokenB, uint256 _amountIn)
        external
        returns (uint256 amountOut);

    function nftAmountToERC20(uint256[] memory _list) external pure returns (uint256 amount);
}
