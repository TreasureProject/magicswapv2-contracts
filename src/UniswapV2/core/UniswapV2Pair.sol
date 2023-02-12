// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Callee.sol";
import "./interfaces/IUniswapV2Factory.sol";

import "./libraries/UniswapV2Math.sol";
import "./libraries/Oracle.sol";

import "./UniswapV2ERC20.sol";

contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using SafeMath for uint256;
    using Oracle for Oracle.Observation[65535];

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant BASIS_POINTS = 10000;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    // decimal points of token0
    uint256 public TOKEN0_DECIMALS;

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    // the most recent price of token1/token0. Inherits decimals of token1.
    uint256 public lastPrice;
    // the most-recently updated index of the observations array
    uint16 public observationIndex;
    // the current maximum number of observations that are being stored
    uint16 public observationCardinality;
    // the next maximum number of observations to store, triggered in observations.write
    uint16 public observationCardinalityNext;

    Oracle.Observation[65535] public override observations;

    uint256 private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, "MagicswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "MagicswapV2: TRANSFER_FAILED");
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "MagicswapV2: FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;

        TOKEN0_DECIMALS = UniswapV2ERC20(_token0).decimals();

        (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(_blockTimestamp());

        observationIndex = 0;
        observationCardinality = cardinality;
        observationCardinalityNext = cardinalityNext;
    }

    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    /// @dev update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "MagicswapV2: OVERFLOW");

        uint32 blockTimestamp;
        uint32 timeElapsed;
        unchecked {
            blockTimestamp = uint32(block.timestamp % 2 ** 32);
            timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        }

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // this is first trade of the block and reserves are not yet updated
            lastPrice = 10 ** TOKEN0_DECIMALS * _reserve1 / _reserve0;

            // write an oracle entry
            (observationIndex, observationCardinality) = observations.write(
                observationIndex, _blockTimestamp(), lastPrice, observationCardinality, observationCardinalityNext
            );
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /// @dev Calculates fees and sends them to beneficiaries
    function _takeFees(uint256 balance0Adjusted, uint256 balance1Adjusted, uint256 amount0In, uint256 amount1In)
        internal
        returns (uint256 balance0, uint256 balance1)
    {
        (, address royaltiesBeneficiary, uint256 royaltiesFee, address protocolFeeBeneficiary, uint256 protocolFee) =
            IUniswapV2Factory(factory).getFeesAndRecipients(address(this));

        address _token0 = token0;
        address _token1 = token1;

        // optimistically set to amount0In
        address feeToken = _token0;
        uint256 amount = amount0In;

        // if amount1In is an input token, use that instead
        if (amount1In > 0) {
            feeToken = _token1;
            amount = amount1In;
        }

        // send royalties
        if (amount > 0 && royaltiesFee > 0) {
            _safeTransfer(feeToken, royaltiesBeneficiary, amount * royaltiesFee / BASIS_POINTS);
        }

        // send protocol fee
        if (amount > 0 && protocolFee > 0) {
            _safeTransfer(feeToken, protocolFeeBeneficiary, amount * protocolFee / BASIS_POINTS);
        }

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        // Make sure that either balance does not go below adjusted balance used for K calcualtions.
        // If balances after fee transfers are above or equal adjusted balances then K still holds.
        require(balance0 >= balance0Adjusted / BASIS_POINTS, "MagicswapV2: balance0Adjusted");
        require(balance1 >= balance1Adjusted / BASIS_POINTS, "MagicswapV2: balance1Adjusted");
    }

    /// @dev this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = UniswapV2Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = UniswapV2Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, "MagicswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @dev this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, "MagicswapV2: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @dev this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, "MagicswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "MagicswapV2: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "MagicswapV2: INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "MagicswapV2: INSUFFICIENT_INPUT_AMOUNT");

        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint256 totalFee = IUniswapV2Factory(factory).getTotalFee(address(this));
            uint256 balance0Adjusted = balance0.mul(BASIS_POINTS).sub(amount0In.mul(totalFee));
            uint256 balance1Adjusted = balance1.mul(BASIS_POINTS).sub(amount1In.mul(totalFee));
            require(
                balance0Adjusted.mul(balance1Adjusted) >= uint256(_reserve0).mul(_reserve1).mul(BASIS_POINTS ** 2),
                "MagicswapV2: K"
            );
            (balance0, balance1) = _takeFees(balance0Adjusted, balance1Adjusted, amount0In, amount1In);
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @dev Read TWAP price
    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (uint256[] memory priceCumulatives)
    {
        return observations.observe(_blockTimestamp(), secondsAgos, lastPrice, observationIndex, observationCardinality);
    }

    /// @dev Increase number of data points for price history
    function increaseObservationCardinalityNext(uint16 _observationCardinalityNext) external override lock {
        uint16 observationCardinalityNextOld = observationCardinalityNext; // for the event
        uint16 observationCardinalityNextNew =
            observations.grow(observationCardinalityNextOld, _observationCardinalityNext);
        observationCardinalityNext = observationCardinalityNextNew;
        if (observationCardinalityNextOld != observationCardinalityNextNew) {
            emit IncreaseObservationCardinalityNext(observationCardinalityNextOld, observationCardinalityNextNew);
        }
    }

    /// @dev force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    /// @dev force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}
