pragma solidity >=0.8.17;

import "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IUniswapV2Callee.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IERC20.sol';

import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './libraries/Oracle.sol';

import './UniswapV2ERC20.sol';

contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;
    using Oracle for Oracle.Observation[65535];

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    // decimal points of token0
    uint256 public TOKEN0_DECIMALS;

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    // the most recent price of token1/token0. Inherits decimals of token1.
    uint256 public lastPrice;
    // the most-recently updated index of the observations array
    uint16 public observationIndex;
    // the current maximum number of observations that are being stored
    uint16 public observationCardinality;
    // the next maximum number of observations to store, triggered in observations.write
    uint16 public observationCardinalityNext;

    Oracle.Observation[65535] public override observations;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'MagicswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'MagicswapV2: TRANSFER_FAILED');
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'MagicswapV2: FORBIDDEN'); // sufficient check
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

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        // TODO: test
        unchecked {
            require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'MagicswapV2: OVERFLOW');

            uint32 blockTimestamp = uint32(block.timestamp % 2**32);
            uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                // this is first trade of the block and reserves are not yet updated
                lastPrice = 10 ** TOKEN0_DECIMALS * _reserve1 / _reserve0;

                // write an oracle entry
                (observationIndex, observationCardinality) = observations.write(
                    observationIndex,
                    _blockTimestamp(),
                    lastPrice,
                    observationCardinality,
                    observationCardinalityNext
                );
            }

            reserve0 = uint112(balance0);
            reserve1 = uint112(balance1);
            blockTimestampLast = blockTimestamp;
            emit Sync(reserve0, reserve1);
        }
    }

    function _takeFees(uint112 _reserve0, uint112 _reserve1, uint amount0Out, uint amount1Out) private {
        (address royaltiesBeneficiary, uint256 royaltiesFee) = IUniswapV2Factory(factory).getRoyaltiesFee(address(this));
        uint protocolFee = IUniswapV2Factory(factory).getProtocolFee(address(this));
        address protocolFeeBeneficiary = IUniswapV2Factory(factory).protocolFeeBeneficiary();

        address _token0 = token0;
        address _token1 = token1;
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

        if (royaltiesFee > 0) {
            if (amount0In > 0) {
                _safeTransfer(_token0, royaltiesBeneficiary, amount0In * royaltiesFee / 10000);
            } else if (amount1In > 0) {
                _safeTransfer(_token1, royaltiesBeneficiary, amount1In * royaltiesFee / 10000);
            }
        }

        if (protocolFee > 0) {
            if (amount0In > 0) {
                _safeTransfer(_token0, protocolFeeBeneficiary, amount0In * protocolFee / 10000);
            } else if (amount1In > 0) {
                _safeTransfer(_token1, protocolFeeBeneficiary, amount1In * protocolFee / 10000);
            }
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'MagicswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'MagicswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'MagicswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'MagicswapV2: INSUFFICIENT_LIQUIDITY');

        // royalties and protocol fees are paid upfront so the rest of the logic just handles lp fees
        _takeFees(_reserve0, _reserve1, amount0Out, amount1Out);

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'MagicswapV2: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'MagicswapV2: INSUFFICIENT_INPUT_AMOUNT');

        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint lpFee = IUniswapV2Factory(factory).getLpFee(address(this));
        uint balance0Adjusted = balance0.mul(10000).sub(amount0In.mul(lpFee));
        uint balance1Adjusted = balance1.mul(10000).sub(amount1In.mul(lpFee));
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(10000**2), 'MagicswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (uint256[] memory priceCumulatives)
    {
        return
            observations.observe(
                _blockTimestamp(),
                secondsAgos,
                lastPrice,
                observationIndex,
                observationCardinality
            );
    }

    function increaseObservationCardinalityNext(uint16 _observationCardinalityNext)
        external
        override
        lock
    {
        uint16 observationCardinalityNextOld = observationCardinalityNext; // for the event
        uint16 observationCardinalityNextNew =
            observations.grow(observationCardinalityNextOld, _observationCardinalityNext);
        observationCardinalityNext = observationCardinalityNextNew;
        if (observationCardinalityNextOld != observationCardinalityNextNew)
            emit IncreaseObservationCardinalityNext(observationCardinalityNextOld, observationCardinalityNextNew);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}
