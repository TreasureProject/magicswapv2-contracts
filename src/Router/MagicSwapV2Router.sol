// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IMagicSwapV2Router.sol";
import "../UniswapV2/periphery/UniswapV2Router02.sol";
import "../UniswapV2/core/interfaces/IUniswapV2Pair.sol";

contract MagicSwapV2Router is IMagicSwapV2Router, UniswapV2Router02 {

    uint256 public constant ONE = 1e18;

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
        uint256 amountToBurn = nftAmountToERC20(_amount);

        if (_from == address(this)) _approveIfNeeded(address(_vault), amountToBurn);

        IERC20(address(_vault)).transferFrom(_from, address(_vault), amountToBurn);
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
        TransferHelper.safeTransfer(address(_tokenA), pair, amountA);
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

        _approveIfNeeded(address(_token), amountMinted);

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
        uint256 _deadline,
        bool _swapLeftover
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

        amountA -= amountBurned;

        if (_swapLeftover) {
            uint256 amountOut = swapLeftover(
                address(_tokenA),
                _tokenB,
                amountA
            );

            amountA = 0;
            amountB += amountOut;
        } else if (amountA > 0) {
            TransferHelper.safeTransfer(address(_tokenA), _to, amountA);
        }

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
        uint256 _deadline,
        bool _swapLeftover
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

        amountToken -= amountBurned;

        if (_swapLeftover) {
            uint256 amountOut = swapLeftover(
                address(_token),
                WETH,
                amountToken
            );

            amountToken = 0;
            amountETH += amountOut;
        } else if (amountToken > 0) {
            TransferHelper.safeTransfer(address(_token), _to, amountToken);
        }

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

        _approveIfNeeded(_path[0], amountIn);

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

        _approveIfNeeded(_path[0], amountIn);

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
        uint256 amountOut = nftAmountToERC20(_amount);

        amounts = _swapTokensForExactTokens(
            amountOut,
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
        uint256 amountOut = nftAmountToERC20(_amount);

        amounts = swapETHForExactTokens(
            amountOut,
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
        uint256 amountIn = _depositVault(_collectionIn, _tokenIdIn, _amountIn, INftVault(_path[0]), address(this));
        address vaultOut = _path[_path.length - 1];
        uint256 amountOutMin = nftAmountToERC20(_amountOut);

        _approveIfNeeded(_path[0], amountIn);

        amounts = _swapExactTokensForTokens(
            amountIn,
            amountOutMin,
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
            INftVault(vaultOut),
            address(this),
            _to
        );

        uint256 dust = amounts[amounts.length - 1] - amountOutMin;

        // send leftover of input token back to the pool and sync
        if (dust > 0) {
            // refund user unused token
            address pair = UniswapV2Library.pairFor(factory, _path[_path.length - 2], vaultOut);
            TransferHelper.safeTransfer(vaultOut, pair, dust);
            IUniswapV2Pair(pair).sync();
        }
    }

    function swapLeftover(address _tokenA, address _tokenB, uint256 _amountIn)
        public
        returns (uint256 amountOut)
    {
        if (_amountIn == 0) return 0;

        address[] memory path = new address[](2);
        path[0] = address(_tokenA);
        path[1] = _tokenB;

        _approveIfNeeded(address(_tokenA), _amountIn);

        // swap leftover to tokenB
        // TODO: can be front-run, issue?
        uint256[] memory amounts = _swapExactTokensForTokens(
            _amountIn,
            1,
            path,
            address(this),
            address(this),
            block.timestamp
        );

        return amounts[1];
    }

    function nftAmountToERC20(uint256[] memory _list) public pure returns (uint256 amount) {
        for (uint256 i = 0; i < _list.length; i++) {
            amount += _list[i];
        }

        amount *= ONE;
    }

    function _approveIfNeeded(address _token, uint256 _amount) internal {
        if (IERC20(_token).allowance(address(this), address(this)) < _amount) {
            SafeERC20.safeApprove(IERC20(_token), address(this), 0);
            SafeERC20.safeApprove(IERC20(_token), address(this), type(uint256).max);
        }
    }
}
