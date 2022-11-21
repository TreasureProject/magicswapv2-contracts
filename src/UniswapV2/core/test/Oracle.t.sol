// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "lib/ERC20Mintable.sol";

import "../UniswapV2Pair.sol";
import "../../periphery/libraries/UniswapV2Library.sol";
import "../../periphery/libraries/OracleLibrary.sol";
import "../UniswapV2Factory.sol";

contract OracleImpl {
    function consult(address pair, uint32 period) public view returns (uint256) {
        return OracleLibrary.consult(pair, period);
    }
}

contract OracleTest is Test {
    uint256 public constant TIMESTAMP = 1668642357;
    uint256 public constant BLOCKTIME = 15;
    uint256 public START_PRICE;

    UniswapV2Pair public pair;
    UniswapV2Factory factory;

    ERC20Mintable public DAI = new ERC20Mintable();
    ERC20Mintable public WETH = new ERC20Mintable();
    OracleImpl public oracleImpl = new OracleImpl();

    address user1 = address(10000001);

    address protocolFeeBeneficiary = address(10000005);

    function setUp() public {
        vm.warp(TIMESTAMP);

        factory = new UniswapV2Factory(150, 30, protocolFeeBeneficiary);

        pair = UniswapV2Pair(factory.createPair(address(WETH), address(DAI)));
        WETH.mint(address(pair), 1000e18);
        DAI.mint(address(pair), 1500000e18);
        pair.mint(user1);

        START_PRICE = 1500000e18 * 1e18 / 1000e18;
    }

    function _mineBlock(uint256 _time) public {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + _time);
    }

    function _swap(uint256 _wethIn, uint256 _daiIn) public returns (uint256 amountOut) {
        _mineBlock(BLOCKTIME);

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        if (_wethIn > 0) {
            uint256 amount1Out = UniswapV2Library.getAmountOut(_wethIn, reserve0, reserve1, address(pair), address(factory));
            WETH.mint(address(pair), _wethIn);
            pair.swap(0, amount1Out, user1, bytes(""));
            amountOut = amount1Out;
        } else if (_daiIn > 0) {
            uint256 amount0Out = UniswapV2Library.getAmountOut(_daiIn, reserve1, reserve0, address(pair), address(factory));
            DAI.mint(address(pair), _daiIn);
            pair.swap(amount0Out, 0, user1, bytes(""));
            amountOut = amount0Out;
        }

    }

    function testTokensOrder() public {
        assertEq(address(WETH), pair.token0());
        assertEq(address(DAI), pair.token1());
    }

    function testConsultOld() public {
        vm.expectRevert(bytes("OLD"));
        oracleImpl.consult(address(pair), 1800);

        assertEq(pair.lastPrice(), 0);

        _swap(0.01e18, 0);
        vm.warp(block.timestamp + BLOCKTIME);
        assertEq(oracleImpl.consult(address(pair), 15), START_PRICE);

        vm.expectRevert(bytes("OLD"));
        oracleImpl.consult(address(pair), 16);

        vm.warp(block.timestamp + 1800 - BLOCKTIME);

        assertEq(oracleImpl.consult(address(pair), 1800), START_PRICE);

        _swap(1e18, 0);

        vm.expectRevert(bytes("OLD"));
        oracleImpl.consult(address(pair), 1);

        vm.warp(block.timestamp + BLOCKTIME);

        assertEq(oracleImpl.consult(address(pair), 15), pair.lastPrice());
    }

    struct TestAction {
        uint256 wethIn;
        uint256 daiIn;
        uint256 timetravelBefore;
        uint256 timetravelAfter;
        uint32 period;
        uint256 TWAP;
        uint16 observationCardinalityNext;
        uint256 observationIndex;
    }

    // workaround for "UnimplementedFeatureError: Copying of type struct memory to storage not yet supported."
    uint256 public constant depositTestCasesLength = 22;

    function getTestAction(uint256 _index) public view returns (TestAction memory) {
        TestAction[depositTestCasesLength] memory testSwapCases = [
            TestAction({
                wethIn: 0.01e18,
                daiIn: 0,
                timetravelBefore: 0,
                timetravelAfter: 60,
                period: 60,
                TWAP: START_PRICE,
                observationCardinalityNext: 120,
                observationIndex: 0
            }),
            TestAction({
                wethIn: 0.01e18,
                daiIn: 0,
                timetravelBefore: 1800,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 1499970495435267142183,
                observationCardinalityNext: 120,
                observationIndex: 1
            }),
            TestAction({
                wethIn: 100e18, // big trade
                daiIn: 0,
                timetravelBefore: 0,
                timetravelAfter: 45,
                period: 1800,
                TWAP: 1499969511978807824364,
                observationCardinalityNext: 120,
                observationIndex: 2
            }),
            TestAction({
                wethIn: 1,
                daiIn: 0,
                timetravelBefore: 0,
                timetravelAfter: 900,
                period: 1800,
                TWAP: 1363107217423634267487,
                observationCardinalityNext: 120,
                observationIndex: 3
            }),
            TestAction({
                wethIn: 0,
                daiIn: 1000000e18, // huge trade
                timetravelBefore: 900,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 1243352310158670807355,
                observationCardinalityNext: 120,
                observationIndex: 4
            }),
            TestAction({
                wethIn: 1,
                daiIn: 0,
                timetravelBefore: 0,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 1263646160072652749974,
                observationCardinalityNext: 120,
                observationIndex: 5
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 45, // 60 sec since huge trade
                timetravelAfter: 0,
                period: 1800,
                TWAP: 1344821559728580520453,
                observationCardinalityNext: 120,
                observationIndex: 5
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 45, // 120 sec since huge trade
                timetravelAfter: 330, // 450 sec since huge trade
                period: 1800,
                TWAP: 1872461657492111028567,
                observationCardinalityNext: 120,
                observationIndex: 5
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 45, // 510 sec since huge trade
                timetravelAfter: 390, // 900 sec since huge trade
                period: 1800,
                TWAP: 2481277154911569307160,
                observationCardinalityNext: 120,
                observationIndex: 5
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 45, // 960 sec since huge trade
                timetravelAfter: 390, // 1350 sec since huge trade
                period: 1800,
                TWAP: 3090092652331027585753,
                observationCardinalityNext: 120,
                observationIndex: 5
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 15, // 1380 sec since huge trade
                timetravelAfter: 400, // 1780 sec since huge trade
                period: 1800,
                TWAP: 3671849683198509940853,
                observationCardinalityNext: 120,
                observationIndex: 5
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 5, // 1800 sec since huge trade
                timetravelAfter: 0,
                period: 1800,
                TWAP: 3678614299836503921727,
                observationCardinalityNext: 120,
                observationIndex: 5
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 45, // 1860 sec since huge trade
                timetravelAfter: 0,
                period: 1800,
                TWAP: 3678614299836503921727,
                observationCardinalityNext: 120,
                observationIndex: 5
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 145, // 2020 sec since huge trade
                timetravelAfter: 0,
                period: 1800,
                TWAP: 3678614299836503921727,
                observationCardinalityNext: 120,
                observationIndex: 5
            }),
            TestAction({
                wethIn: 250e18,
                daiIn: 0,
                timetravelBefore: 0,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 3678614299836503921715,
                observationCardinalityNext: 120,
                observationIndex: 6
            }),
            TestAction({
                wethIn: 1,
                daiIn: 0,
                timetravelBefore: 0,
                timetravelAfter: 900,
                period: 1800,
                TWAP: 2783849579014797350624,
                observationCardinalityNext: 120,
                observationIndex: 7
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 885,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 1918421406416753290062,
                observationCardinalityNext: 120,
                observationIndex: 7
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 885,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 1918421406416753290062,
                observationCardinalityNext: 120,
                observationIndex: 7
            }),
            TestAction({
                wethIn: 0,
                daiIn: 500000e18,
                timetravelBefore: 885,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 1918421406416753290057,
                observationCardinalityNext: 120,
                observationIndex: 8
            }),
            TestAction({
                wethIn: 1,
                daiIn: 0,
                timetravelBefore: 885,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 2554290763490825493524,
                observationCardinalityNext: 120,
                observationIndex: 9
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 885,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 3190160120564897696992,
                observationCardinalityNext: 120,
                observationIndex: 9
            }),
            TestAction({
                wethIn: 0,
                daiIn: 0,
                timetravelBefore: 885,
                timetravelAfter: 0,
                period: 1800,
                TWAP: 3190160120564897696992,
                observationCardinalityNext: 120,
                observationIndex: 9
            })
        ];

        return testSwapCases[_index];
    }

    function testConsult() public {
        for (uint256 i = 0; i < depositTestCasesLength; i++) {
            TestAction memory testCase = getTestAction(i);

            vm.warp(block.timestamp + testCase.timetravelBefore);
            _swap(testCase.wethIn, testCase.daiIn);
            vm.warp(block.timestamp + testCase.timetravelAfter);

            assertEq(oracleImpl.consult(address(pair), testCase.period), testCase.TWAP);

            if (testCase.observationCardinalityNext > pair.observationCardinalityNext()) {
                pair.increaseObservationCardinalityNext(testCase.observationCardinalityNext);
            }

            assertEq(pair.observationIndex(), testCase.observationIndex);
        }
    }

    function testObservationsSingleCardinality() public {
        uint32 blockTimestamp;
        uint256 priceCumulative;
        bool initialized;

        (blockTimestamp, priceCumulative, initialized) = pair.observations(pair.observationIndex());
        assertEq(blockTimestamp, block.timestamp);
        assertEq(priceCumulative, 0);
        assertEq(initialized, true);

        _swap(0.01e18, 0);

        (blockTimestamp, priceCumulative, initialized) = pair.observations(pair.observationIndex());
        assertEq(blockTimestamp, block.timestamp);
        assertEq(priceCumulative, START_PRICE * BLOCKTIME);
        assertEq(initialized, true);

        _swap(1e18, 0);

        (blockTimestamp, priceCumulative, initialized) = pair.observations(pair.observationIndex());
        assertEq(blockTimestamp, block.timestamp);
        assertEq(priceCumulative, START_PRICE * BLOCKTIME + pair.lastPrice() * BLOCKTIME);
        assertEq(initialized, true);

        vm.warp(block.timestamp + BLOCKTIME);

        assertEq(oracleImpl.consult(address(pair), 15), pair.lastPrice());
    }

    function _assertCardinality(uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext) public {
        assertEq(pair.observationIndex(), observationIndex);
        assertEq(pair.observationCardinality(), observationCardinality);
        assertEq(pair.observationCardinalityNext(), observationCardinalityNext);
    }

    function testIncreaseObservationCardinalityNext() public {
        _swap(1e18, 0);
        _assertCardinality(0, 1, 1);

        _swap(1e18, 0);
        _assertCardinality(0, 1, 1);

        pair.increaseObservationCardinalityNext(3);
        _assertCardinality(0, 1, 3);

        _swap(1e18, 0);
        _assertCardinality(1, 3, 3);

        _swap(1e18, 0);
        _assertCardinality(2, 3, 3);

        _swap(1e18, 0);
        _assertCardinality(0, 3, 3);

        pair.increaseObservationCardinalityNext(10);
        _assertCardinality(0, 3, 10);

        _swap(1e18, 0);
        _assertCardinality(1, 3, 10);

        _swap(1e18, 0);
        _assertCardinality(2, 3, 10);

        _swap(1e18, 0);
        _assertCardinality(3, 10, 10);

        for (uint256 i = 0; i < 6; i++) {_swap(1e18, 0);}
        _assertCardinality(9, 10, 10);

        _swap(1e18, 0);
        _assertCardinality(0, 10, 10);

        pair.increaseObservationCardinalityNext(15);
        _assertCardinality(0, 10, 15);

        for (uint256 i = 0; i < 9; i++) {_swap(1e18, 0);}
        _assertCardinality(9, 10, 15);

        _swap(1e18, 0);
        _assertCardinality(10, 15, 15);

        for (uint256 i = 0; i < 4; i++) {_swap(1e18, 0);}
        _assertCardinality(14, 15, 15);

        _swap(1e18, 0);
        _assertCardinality(0, 15, 15);
    }

    function testObservationsMultipleCardinality() public {
        uint32 blockTimestamp;
        uint256 priceCumulative;
        bool initialized;

        _swap(0.01e18, 0);
        assertEq(pair.lastPrice(), START_PRICE);

        (uint32 blockTimestamp0, uint256 priceCumulative0, bool initialized0) = pair.observations(0);
        assertEq(blockTimestamp0, block.timestamp);
        assertEq(priceCumulative0, START_PRICE * BLOCKTIME);
        assertEq(initialized0, true);

        pair.increaseObservationCardinalityNext(3);

        _swap(100e18, 0);

        (blockTimestamp, priceCumulative, initialized) = pair.observations(0);
        assertEq(blockTimestamp, blockTimestamp0);
        assertEq(priceCumulative, priceCumulative0);
        assertEq(initialized, initialized0);

        (blockTimestamp, priceCumulative, initialized) = pair.observations(1);
        assertEq(blockTimestamp, blockTimestamp0 + BLOCKTIME);
        assertEq(priceCumulative, priceCumulative0 + pair.lastPrice() * BLOCKTIME);
        assertEq(initialized, true);
    }
}
