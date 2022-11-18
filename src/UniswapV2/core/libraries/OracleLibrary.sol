pragma solidity >=0.8.17;

import '../interfaces/IUniswapV2Pair.sol';

/// @title Oracle library
/// @notice Provides functions to integrate with MagicswapV2 pool oracle
library OracleLibrary {
    /// @notice Fetches time-weighted average price using MagicswapV2 oracle
    /// @param pool Address of Uniswap V3 pool that we want to observe
    /// @param period Number of seconds in the past to start calculating time-weighted average
    /// @return timeWeightedAveragePrice The time-weighted average tick from (block.timestamp - period) to block.timestamp
    function consult(address pool, uint32 period) internal view returns (uint256 timeWeightedAveragePrice) {
        require(period != 0, 'BP');

        uint32[] memory secondAgos = new uint32[](2);
        secondAgos[0] = period;
        secondAgos[1] = 0;

        uint256[] memory priceCumulatives = IUniswapV2Pair(pool).observe(secondAgos);
        uint256 priceCumulativesDelta = priceCumulatives[1] - priceCumulatives[0];

        timeWeightedAveragePrice = priceCumulativesDelta / period;
    }
}
