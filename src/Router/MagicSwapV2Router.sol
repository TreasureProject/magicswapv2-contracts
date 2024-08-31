// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IMagicSwapV2Router.sol";
import "../UniswapV2/periphery/UniswapV2Router02.sol";
import "../UniswapV2/core/interfaces/IUniswapV2Pair.sol";

contract MagicSwapV2Router is IMagicSwapV2Router, UniswapV2Router02 {
    uint256 public constant ONE = 1e18;
    address public constant BURN_ADDRESS = address(0xdead);

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
                IERC1155(_collection[i]).safeTransferFrom(
                    msg.sender, address(_vault), _tokenId[i], _amount[i], bytes("")
                );
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
        IERC20 vaultToken = IERC20(address(_vault));
        uint256 amountToBurn = nftAmountToERC20(_amount);
        uint256 fromBalance = vaultToken.balanceOf(_from);
        uint256 totalSupply = vaultToken.totalSupply();

        /// @dev if user withdraws all NFT tokens but does not have totalSupply of ERC20 tokens (some are locked
        ///      in UniV2 pool), we optimistically assume that user has enough and adjust `amountToBurn`
        ///      to user balance. If user balance does not meet required minimum then Vault will revert anyway.
        if (amountToBurn == totalSupply && fromBalance < totalSupply) {
            amountToBurn = fromBalance;
        }

        if (_from == address(this)) _approveIfNeeded(address(_vault), amountToBurn);

        vaultToken.transferFrom(_from, address(_vault), amountToBurn);
        amountBurned = _vault.withdrawBatch(_to, _collection, _tokenId, _amount);

        if (amountToBurn != amountBurned) revert MagicSwapV2WrongAmounts();
    }

    /// @inheritdoc IMagicSwapV2Router
    function addLiquidityNFT(
        NftVaultLiquidityData calldata _vault,
        address _tokenB,
        uint256 _amountBDesired,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external ensure(_deadline) returns (uint256 amountA, uint256 amountB, uint256 lpAmount) {
        uint256 amountAMinted = _depositVault(_vault.collection, _vault.tokenId, _vault.amount, _vault.token, address(this));

        (amountA, amountB) =
            _addLiquidity(address(_vault.token), _tokenB, amountAMinted, _amountBDesired, amountAMinted, _amountBMin);

        if(amountAMinted != amountA) revert MagicSwapV2WrongAmountDeposited();

        address pair = UniswapV2Library.pairFor(factory, address(_vault.token), _tokenB);
        TransferHelper.safeTransfer(address(_vault.token), pair, amountA);
        TransferHelper.safeTransferFrom(_tokenB, msg.sender, pair, amountB);
        lpAmount = IUniswapV2Pair(pair).mint(_to);

        emit NFTLiquidityAdded(_to, pair, _vault);
    }

    /// @inheritdoc IMagicSwapV2Router
    function addLiquidityNFTETH(
        NftVaultLiquidityData calldata _vault,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 lpAmount) {
        uint256 amountMinted = _depositVault(_vault.collection, _vault.tokenId, _vault.amount, _vault.token, address(this));

        _approveIfNeeded(address(_vault.token), amountMinted);

        (amountToken, amountETH, lpAmount) =
            _addLiquidityETH(address(_vault.token), amountMinted, amountMinted, _amountETHMin, address(this), _to, _deadline);

        address pair = UniswapV2Library.pairFor(factory, address(_vault.token), WETH);

        emit NFTLiquidityAdded(_to, pair, _vault);
    }

    /// @inheritdoc IMagicSwapV2Router
    function addLiquidityNFTNFT(
        NftVaultLiquidityData calldata _vaultA,
        NftVaultLiquidityData calldata _vaultB,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external ensure(_deadline) returns (uint256 amountA, uint256 amountB, uint256 lpAmount) {
        uint256 amountAMinted = _depositVault(_vaultA.collection, _vaultA.tokenId, _vaultA.amount, _vaultA.token, address(this));
        uint256 amountBMinted = _depositVault(_vaultB.collection, _vaultB.tokenId, _vaultB.amount, _vaultB.token, address(this));

        (amountA, amountB) =
            _addLiquidity(address(_vaultA.token), address(_vaultB.token), amountAMinted, amountBMinted, _amountAMin, _amountBMin);

        if (amountAMinted != amountA) {
            if (amountAMinted < amountA) {
                revert MagicSwapV2WrongAmountADeposited();
            }
            
            TransferHelper.safeTransfer(address(_vaultA.token), BURN_ADDRESS, amountAMinted - amountA);
        }

        if (amountBMinted != amountB) {
            if (amountBMinted < amountB) {
                revert MagicSwapV2WrongAmountBDeposited();
            }

            TransferHelper.safeTransfer(address(_vaultB.token), BURN_ADDRESS, amountBMinted - amountB);
        }

        address pair = UniswapV2Library.pairFor(factory, address(_vaultA.token), address(_vaultB.token));
        TransferHelper.safeTransfer(address(_vaultA.token), pair, amountA);
        TransferHelper.safeTransfer(address(_vaultB.token), pair, amountB);
        lpAmount = IUniswapV2Pair(pair).mint(_to);

        emit NFTNFTLiquidityAdded(_to, pair, _vaultA, _vaultB);
    }

    /// @inheritdoc IMagicSwapV2Router
    function removeLiquidityNFT(
        NftVaultLiquidityData calldata _vault,
        address _tokenB,
        uint256 _lpAmount,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline,
        bool _swapLeftover
    ) external returns (uint256 amountA, uint256 amountB) {
        (amountA, amountB) =
            removeLiquidity(address(_vault.token), _tokenB, _lpAmount, _amountAMin, _amountBMin, address(this), _deadline);

        // withdraw NFTs and send to user
        uint256 amountBurned = _withdrawVault(_vault.collection, _vault.tokenId, _vault.amount, _vault.token, address(this), _to);

        amountA -= amountBurned;

        if (_swapLeftover) {
            uint256 amountOut = swapLeftover(address(_vault.token), _tokenB, amountA);

            amountA = 0;
            amountB += amountOut;
        } else if (amountA > 0) {
            TransferHelper.safeTransfer(address(_vault.token), _to, amountA);
        }

        TransferHelper.safeTransfer(_tokenB, _to, amountB);

        address pair = UniswapV2Library.pairFor(factory, address(_vault.token), _tokenB);

        emit NFTLiquidityRemoved(_to, pair, _vault);
    }

    /// @inheritdoc IMagicSwapV2Router
    function removeLiquidityNFTETH(
        NftVaultLiquidityData calldata _vault,
        uint256 _lpAmount,
        uint256 _amountTokenMin,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline,
        bool _swapLeftover
    ) external returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) =
            removeLiquidity(address(_vault.token), WETH, _lpAmount, _amountTokenMin, _amountETHMin, address(this), _deadline);

        // withdraw NFTs and send to user
        uint256 amountBurned = _withdrawVault(_vault.collection, _vault.tokenId, _vault.amount, _vault.token, address(this), _to);

        amountToken -= amountBurned;

        if (_swapLeftover) {
            uint256 amountOut = swapLeftover(address(_vault.token), WETH, amountToken);

            amountToken = 0;
            amountETH += amountOut;
        } else if (amountToken > 0) {
            TransferHelper.safeTransfer(address(_vault.token), _to, amountToken);
        }

        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(_to, amountETH);

        address pair = UniswapV2Library.pairFor(factory, address(_vault.token), WETH);

        emit NFTLiquidityRemoved(_to, pair, _vault);
    }

    /// @inheritdoc IMagicSwapV2Router
    function removeLiquidityNFTNFT(
        NftVaultLiquidityData calldata _vaultA,
        NftVaultLiquidityData calldata _vaultB,
        uint256 _lpAmount,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        (amountA, amountB) =
            removeLiquidity(address(_vaultA.token), address(_vaultB.token), _lpAmount, _amountAMin, _amountBMin, address(this), _deadline);

        // withdraw NFTs and send to user
        uint256 amountBurnedA = _withdrawVault(_vaultA.collection, _vaultA.tokenId, _vaultA.amount, _vaultA.token, address(this), _to);
        uint256 amountBurnedB = _withdrawVault(_vaultB.collection, _vaultB.tokenId, _vaultB.amount, _vaultB.token, address(this), _to);

        amountA -= amountBurnedA;
        amountB -= amountBurnedB;

        if (amountA > 0) {
            TransferHelper.safeTransfer(address(_vaultA.token), BURN_ADDRESS, amountA);
        }

        if (amountB > 0) {
            TransferHelper.safeTransfer(address(_vaultB.token), BURN_ADDRESS, amountB);
        }

        address pair = UniswapV2Library.pairFor(factory, address(_vaultA.token), address(_vaultB.token));
        
        emit NFTNFTLiquidityRemoved(_to, pair, _vaultA, _vaultB);
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

        amounts = _swapExactTokensForTokens(amountIn, _amountOutMin, _path, address(this), _to, _deadline);
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
        if(_path[_path.length - 1] != WETH) revert MagicSwapV2InvalidPath();

        uint256 amountIn = _depositVault(_collection, _tokenId, _amount, INftVault(_path[0]), address(this));

        _approveIfNeeded(_path[0], amountIn);

        amounts = _swapExactTokensForTokens(amountIn, _amountOutMin, _path, address(this), address(this), _deadline);

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

        amounts = _swapTokensForExactTokens(amountOut, _amountInMax, _path, msg.sender, address(this), _deadline);

        // withdraw NFTs and send to user
        _withdrawVault(_collection, _tokenId, _amount, INftVault(_path[_path.length - 1]), address(this), _to);
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

        amounts = swapETHForExactTokens(amountOut, _path, address(this), _deadline);

        // withdraw NFTs and send to user
        _withdrawVault(_collection, _tokenId, _amount, INftVault(_path[_path.length - 1]), address(this), _to);
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

        amounts = _swapExactTokensForTokens(amountIn, amountOutMin, _path, address(this), address(this), _deadline);

        // withdraw NFTs and send to user
        _withdrawVault(_collectionOut, _tokenIdOut, _amountOut, INftVault(vaultOut), address(this), _to);

        uint256 dust = amounts[amounts.length - 1] - amountOutMin;

        // send leftover of input token back to the pool and sync
        if (dust > 0) {
            // refund user unused token
            address pair = UniswapV2Library.pairFor(factory, _path[_path.length - 2], vaultOut);
            TransferHelper.safeTransfer(vaultOut, pair, dust);
            IUniswapV2Pair(pair).sync();
        }
    }

    function swapLeftover(address _tokenA, address _tokenB, uint256 _amountIn) internal returns (uint256 amountOut) {
        if (_amountIn == 0) return 0;

        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = _tokenB;

        _approveIfNeeded(_tokenA, _amountIn);

        // swap leftover to tokenB
        // TODO: can be front-run, issue?
        uint256[] memory amounts =
            _swapExactTokensForTokens(_amountIn, 1, path, address(this), address(this), block.timestamp);

        return amounts[1];
    }

    function nftAmountToERC20(uint256[] memory _list) internal pure returns (uint256 amount) {
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
