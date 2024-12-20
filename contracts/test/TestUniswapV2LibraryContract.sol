// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {UniswapV2Library} from "../UniswapV2/periphery/libraries/UniswapV2Library.sol";

contract TestUniswapV2LibraryContract {
    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        return UniswapV2Library.sortTokens(tokenA, tokenB);
    }

    function pairFor(address factory, address tokenA, address tokenB) public pure returns (address pair) {
        return UniswapV2Library.pairFor(factory, tokenA, tokenB);
    }

    function getReserves(address factory, address tokenA, address tokenB)
        public
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        return UniswapV2Library.getReserves(factory, tokenA, tokenB);
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, address pair, address factory)
        public
        view
        returns (uint256 amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut, pair, factory);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, address pair, address factory)
        public
        view
        returns (uint256 amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut, pair, factory);
    }

    function getAmountsOut(address factory, uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(address factory, uint256 amountOut, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}
