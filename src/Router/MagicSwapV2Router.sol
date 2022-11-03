pragma solidity >=0.8.17;

import "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

import "./IMagicSwapV2Router.sol";
import "../UniswapV2/periphery/UniswapV2Router02.sol";

contract MagicSwapV2Router is IMagicSwapV2Router, UniswapV2Router02 {

    constructor(address _factory, address _WETH) UniswapV2Router02(_factory, _WETH) {}

    /// @inheritdoc IMagicSwapV2Router
    function depositVault(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _vault,
        address _to
    ) external returns (uint256 amountMinted) {
        amountMinted = _depositVault(_collection, _tokenId, _amount, _vault, _to);
    }

    function _depositVault(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _vault,
        address _to
    ) internal returns (uint256 amountMinted) {
        for (uint256 i = 0; i < _collection.length; i++) {
            INftVault.CollectionData memory collectionData = _vault.getAllowedCollectionData(_collection[i]);
            if (collectionData.nftType == INftVault.NftType.ERC721) {
                IERC721(_collection[i]).safeTransferFrom(msg.sender, address(_vault), _tokenId[i]);
            } else if (collectionData.nftType == INftVault.NftType.ERC1155) {
                IERC1155(_collection[i]).safeTransferFrom(msg.sender, address(_vault), _tokenId[i], _amount[i], bytes(""));
            } else {
                revert INftVault.UnsupportedNft();
            }
        }

        amountMinted = _vault.depositBatch(_to, _collection, _tokenId, _amount);
    }

    /// @inheritdoc IMagicSwapV2Router
    function withdrawVault(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _vault,
        address _to
    ) external returns (uint256 amountBurned) {
        amountBurned = _withdrawVault(_collection, _tokenId, _amount, _vault, msg.sender, _to);
    }

    function _withdrawVault(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _vault,
        address _from,
        address _to
    ) internal returns (uint256 amountBurned) {
        amountBurned = getSum(_amount);

        IERC20(address(_vault)).transferFrom(_from, address(_vault), amountBurned);
        amountBurned = _vault.withdrawBatch(_to, _collection, _tokenId, _amount);
    }

    /// @inheritdoc IMagicSwapV2Router
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
    ) external ensure(_deadline) returns (uint256 amountA, uint256 amountB, uint256 lpAmount) {
        uint256 amountAMinted = _depositVault(_collection, _tokenId, _amount, _tokenA, address(this));

        (amountA, amountB) = _addLiquidity(
            address(_tokenA),
            _tokenB,
            amountAMinted,
            _amountBDesired,
            amountAMinted,
            _amountBMin
        );

        require(amountAMinted == amountA, "Wrong amount deposited");

        address pair = UniswapV2Library.pairFor(factory, address(_tokenA), _tokenB);
        TransferHelper.safeTransferFrom(address(_tokenA), address(this), pair, amountA);
        TransferHelper.safeTransferFrom(_tokenB, msg.sender, pair, amountB);
        lpAmount = IUniswapV2Pair(pair).mint(_to);
    }

    /// @inheritdoc IMagicSwapV2Router
    function addLiquidityNFTETH(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _token,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 lpAmount) {
        uint256 amountMinted = _depositVault(_collection, _tokenId, _amount, _token, address(this));

        (amountToken, amountETH, lpAmount) = _addLiquidityETH(
            address(_token),
            amountMinted,
            amountMinted,
            _amountETHMin,
            address(this),
            _to,
            _deadline
        );
    }

    /// @inheritdoc IMagicSwapV2Router
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
        uint256 _deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        (amountA, amountB) = removeLiquidity(
            address(_tokenA),
            _tokenB,
            _lpAmount,
            _amountAMin,
            _amountBMin,
            address(this),
            _deadline
        );

        // withdraw NFTs and send to user
        uint256 amountBurned = _withdrawVault(
            _collection,
            _tokenId,
            _amount,
            _tokenA,
            address(this),
            _to
        );

        (amountA, amountB) = swapLeftoverIfAny(
            address(_tokenA),
            _tokenB,
            amountA,
            amountBurned,
            amountB
        );

        TransferHelper.safeTransfer(_tokenB, _to, amountB);
    }

    /// @inheritdoc IMagicSwapV2Router
    function removeLiquidityNFTETH(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        INftVault _token,
        uint256 _lpAmount,
        uint256 _amountTokenMin,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            address(_token),
            WETH,
            _lpAmount,
            _amountTokenMin,
            _amountETHMin,
            address(this),
            _deadline
        );

        // withdraw NFTs and send to user
        uint256 amountBurned = _withdrawVault(
            _collection,
            _tokenId,
            _amount,
            _token,
            address(this),
            _to
        );

        (amountToken, amountETH) = swapLeftoverIfAny(
            address(_token),
            WETH,
            amountToken,
            amountBurned,
            amountETH
        );

        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(_to, amountETH);
    }

    /// @inheritdoc IMagicSwapV2Router
    function swapNftForTokens(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory amounts) {
        uint256 amountIn = _depositVault(_collection, _tokenId, _amount, INftVault(_path[0]), address(this));

        amounts = _swapExactTokensForTokens(
            amountIn,
            _amountOutMin,
            _path,
            address(this),
            _to,
            _deadline
        );
    }

    /// @inheritdoc IMagicSwapV2Router
    function swapNftForETH(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256[] memory amounts) {
        require(_path[_path.length - 1] == WETH, 'MagicswapV2Router: INVALID_PATH');

        uint256 amountIn = _depositVault(_collection, _tokenId, _amount, INftVault(_path[0]), address(this));

        amounts = _swapExactTokensForTokens(
            amountIn,
            _amountOutMin,
            _path,
            address(this),
            address(this),
            _deadline
        );

        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(_to, amounts[amounts.length - 1]);
    }

    /// @inheritdoc IMagicSwapV2Router
    function swapTokensForNft(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        uint256 _amountInMax,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory amounts) {
        amounts = _swapTokensForExactTokens(
            getSum(_amount),
            _amountInMax,
            _path,
            msg.sender,
            address(this),
            _deadline
        );

        // withdraw NFTs and send to user
        _withdrawVault(
            _collection,
            _tokenId,
            _amount,
            INftVault(_path[_path.length - 1]),
            address(this),
            _to
        );
    }

    /// @inheritdoc IMagicSwapV2Router
    function swapETHForNft(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256[] memory amounts) {
        amounts = swapETHForExactTokens(
            getSum(_amount),
            _path,
            address(this),
            _deadline
        );

        // withdraw NFTs and send to user
        _withdrawVault(
            _collection,
            _tokenId,
            _amount,
            INftVault(_path[_path.length - 1]),
            address(this),
            _to
        );
    }

    /// @inheritdoc IMagicSwapV2Router
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
    ) external returns (uint256[] memory amounts) {
        uint256 amountInMax = _depositVault(_collectionIn, _tokenIdIn, _amountIn, INftVault(_path[0]), address(this));

        amounts = _swapTokensForExactTokens(
            getSum(_amountOut),
            amountInMax,
            _path,
            address(this),
            address(this),
            _deadline
        );

        // withdraw NFTs and send to user
        _withdrawVault(
            _collectionOut,
            _tokenIdOut,
            _amountOut,
            INftVault(_path[_path.length - 1]),
            address(this),
            _to
        );

        // TODO: send back to the pool and sync
        if (amounts[0] < amountInMax) {
            // refund user unused token
            TransferHelper.safeTransfer(_path[0], _to, amountInMax - amounts[0]);
        }
    }

    function swapLeftoverIfAny(
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountABurned,
        uint256 _amountB
    ) public returns (uint256 newAmountA, uint256 newAmountB) {
        newAmountA = _amountA;
        newAmountB = _amountB;

        if (_amountA - _amountABurned > 0) {
            address[] memory path = new address[](2);
            path[0] = address(_tokenA);
            path[1] = _tokenB;

            // swap leftover to tokenB and send to user
            // TODO: can be front-run, issue?
            uint256[] memory amounts = swapExactTokensForTokens(
                _amountA - _amountABurned,
                1,
                path,
                address(this),
                block.timestamp
            );

            newAmountA = _amountABurned;
            newAmountB += amounts[1];
        }
    }

    function getSum(uint256[] memory _list) public pure returns (uint256 sum) {
        for (uint256 i = 0; i < _list.length; i++) {
            sum += _list[i];
        }
    }

    // UniV2
    // - built-in TWAP
    // NFTX Tokenized Vault
    // - Allow user to redeem their own NFTs
    // Lending safety utilities

    // - make vault accept ERC1155 and potentially a mix of different token
    // - what happens when everyone remove liquidity and always want more NFTs
    // - support NFT farming/rewards
    // - use admin when needed
    // - bootstrapping pool?
    // - royalties? check niftyswap
    // - Adding and Removing fractions of NFT liquidity is forbidden. Rounter will force sell or buy into the pool. LP can choose to sell or buy.

    // - what happens when everyone remove liquidity and always want more NFTs
    // - support NFT farming/rewards
    // - use admin when needed
    // - bootstrapping pool?
    // - Adding and Removing fractions of NFT liquidity is forbidden. Rounter will force sell or buy into the pool. LP can choose to sell or buy.
}
