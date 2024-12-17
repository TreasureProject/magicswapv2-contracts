// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "lib/ERC20Mintable.sol";

import "../UniswapV2Pair.sol";
import "../../periphery/libraries/UniswapV2Library.sol";
import "../UniswapV2Factory.sol";
import "./mock/UniswapV2PairOriginal.sol";

contract UniswapV2PairTest is Test {
    UniswapV2Pair pair;
    UniswapV2Pair pairWithFees;
    UniswapV2PairOriginal pairOriginal;
    UniswapV2Factory factory;

    ERC20Mintable token0;
    ERC20Mintable token1;

    address user1 = address(10000001);
    address user2 = address(10000002);
    address user3 = address(10000003);
    address user4 = address(10000004);

    address protocolFeeBeneficiary = address(10000005);
    address royaltiesBeneficiary = address(10000006);

    uint256 royaltiesFee = 50;
    uint256 protocolFee = 50;

    function setUp() public {
        address tokenA = address(new ERC20Mintable());
        address tokenB = address(new ERC20Mintable());
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        token0 = ERC20Mintable(tokenA);
        token1 = ERC20Mintable(tokenB);

        factory = new UniswapV2Factory(0, 30, protocolFeeBeneficiary);

        vm.startPrank(address(factory));

        pair = new UniswapV2Pair();
        pair.initialize(address(token0), address(token1));

        pairOriginal = new UniswapV2PairOriginal();
        pairOriginal.initialize(address(token0), address(token1));

        pairWithFees = UniswapV2Pair(factory.createPair(address(token0), address(token1)));

        vm.stopPrank();

        factory.setRoyaltiesFee(address(pairWithFees), royaltiesBeneficiary, royaltiesFee);
        factory.setProtocolFee(address(pairWithFees), protocolFee, true);
        factory.setProtocolFeeBeneficiary(protocolFeeBeneficiary);
    }

    function _assertPairs(UniswapV2Pair _pair, UniswapV2PairOriginal _pairOriginal) public {
        assertEq(_pair.token0(), _pairOriginal.token0());
        assertEq(_pair.token1(), _pairOriginal.token1());

        (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) = _pair.getReserves();
        (uint112 _reserve0Org, uint112 _reserve1Org, uint32 _blockTimestampLastOrg) = _pairOriginal.getReserves();

        assertEq(_reserve0, _reserve0Org);
        assertEq(_reserve1, _reserve1Org);
        assertEq(_blockTimestampLast, _blockTimestampLastOrg);

        assertEq(_pair.factory(), _pairOriginal.factory());

        assertEq(token0.balanceOf(address(_pair)), token0.balanceOf(address(_pairOriginal)));
        assertEq(token1.balanceOf(address(_pair)), token1.balanceOf(address(_pairOriginal)));
    }

    function _addLiquidity(address _pair, uint256 _amount0, uint256 _amount1, address _to)
        public
        returns (uint256 liquidity)
    {
        token0.mint(_pair, _amount0);
        token1.mint(_pair, _amount1);

        liquidity = UniswapV2Pair(_pair).mint(_to);
    }

    function testMintBurnRegression(uint112 _amount0, uint112 _amount1) public {
        vm.assume(_amount0 > pair.MINIMUM_LIQUIDITY());
        vm.assume(_amount1 > pair.MINIMUM_LIQUIDITY());

        uint256 liquidity = _addLiquidity(address(pair), _amount0, _amount1, user1);
        assertEq(liquidity, pair.totalSupply() - pair.MINIMUM_LIQUIDITY());

        uint256 liquidityOriginal = _addLiquidity(address(pairOriginal), _amount0, _amount1, user1);
        assertEq(liquidityOriginal, pairOriginal.totalSupply() - pairOriginal.MINIMUM_LIQUIDITY());

        assertEq(liquidity, liquidityOriginal);

        _assertPairs(pair, pairOriginal);

        vm.prank(user1);
        pair.transfer(address(pair), liquidity);
        (uint256 amount0, uint256 amount1) = pair.burn(user1);

        vm.prank(user1);
        pairOriginal.transfer(address(pairOriginal), liquidity);
        (uint256 amount0Org, uint256 amount1Org) = pairOriginal.burn(user2);

        assertEq(amount0, amount0Org);
        assertEq(amount1, amount1Org);

        _assertPairs(pair, pairOriginal);
    }

    function _swap(address _pair, uint256 _amount0In, uint256 _amount1In, address _to)
        public
        returns (uint256 amountOut)
    {
        (uint112 reserve0, uint112 reserve1,) = UniswapV2Pair(_pair).getReserves();
        token0.mint(_pair, _amount0In);
        token1.mint(_pair, _amount1In);

        if (_amount0In > _amount1In) {
            uint256 amount1Out = UniswapV2Library.getAmountOut(_amount0In, reserve0, reserve1, _pair, address(factory));
            UniswapV2Pair(_pair).swap(0, amount1Out, _to, bytes(""));
            amountOut = amount1Out;
        } else {
            uint256 amount0Out = UniswapV2Library.getAmountOut(_amount1In, reserve1, reserve0, _pair, address(factory));
            UniswapV2Pair(_pair).swap(amount0Out, 0, _to, bytes(""));
            amountOut = amount0Out;
        }
    }

    function testSwapRegression(uint96 _reserve0, uint96 _reserve1, uint72 _amount0In, uint72 _amount1In) public {
        _reserve0 = uint96(bound(_reserve0, 10000e18, type(uint96).max));
        _reserve1 = uint96(bound(_reserve1, 10000e18, type(uint96).max));
        _amount0In = uint72(bound(_amount0In, 0.001e18, type(uint72).max));
        _amount1In = uint72(bound(_amount1In, 0.001e18, type(uint72).max));

        _addLiquidity(address(pair), _reserve0, _reserve1, user3);
        _addLiquidity(address(pairOriginal), _reserve0, _reserve1, user3);

        _assertPairs(pair, pairOriginal);

        assertEq(token0.balanceOf(user1), 0);
        assertEq(token1.balanceOf(user1), 0);

        uint256 amount1Out = _swap(address(pair), _amount0In, 0, user1);
        assertEq(token0.balanceOf(user1), 0);
        assertEq(token1.balanceOf(user1), amount1Out);

        assertEq(token0.balanceOf(user2), 0);
        assertEq(token1.balanceOf(user2), 0);

        uint256 amount1OutOrg = _swap(address(pairOriginal), _amount0In, 0, user2);
        assertEq(token0.balanceOf(user2), 0);
        assertEq(token1.balanceOf(user2), amount1OutOrg);

        assertEq(amount1Out, amount1OutOrg);
        _assertPairs(pair, pairOriginal);

        for (uint256 i = 0; i < 20; i++) {
            if (i % 2 == 0) {
                _swap(address(pair), _amount0In, 0, user1);
                _swap(address(pairOriginal), _amount0In, 0, user2);
            } else {
                _swap(address(pair), 0, _amount1In, user1);
                _swap(address(pairOriginal), 0, _amount1In, user2);
            }
        }

        _assertPairs(pair, pairOriginal);
    }

    function testSkimRegression(uint96 _reserve0, uint96 _reserve1, uint72 _amount0In, uint72 _amount1In) public {
        _reserve0 = uint96(bound(_reserve0, 10000e18, type(uint96).max));
        _reserve1 = uint96(bound(_reserve1, 10000e18, type(uint96).max));
        _amount0In = uint72(bound(_amount0In, 0.001e18, type(uint72).max));
        _amount1In = uint72(bound(_amount1In, 0.001e18, type(uint72).max));

        _addLiquidity(address(pair), _reserve0, _reserve1, user3);
        _addLiquidity(address(pairOriginal), _reserve0, _reserve1, user3);

        _assertPairs(pair, pairOriginal);

        assertEq(token0.balanceOf(user1), 0);
        assertEq(token1.balanceOf(user1), 0);

        token0.mint(address(pair), _amount0In);
        token1.mint(address(pair), _amount1In);
        pair.skim(user1);
        assertEq(token0.balanceOf(user1), _amount0In);
        assertEq(token1.balanceOf(user1), _amount1In);

        assertEq(token0.balanceOf(user2), 0);
        assertEq(token1.balanceOf(user2), 0);

        token0.mint(address(pairOriginal), _amount0In);
        token1.mint(address(pairOriginal), _amount1In);
        pairOriginal.skim(user2);
        assertEq(token0.balanceOf(user2), _amount0In);
        assertEq(token1.balanceOf(user2), _amount1In);

        _assertPairs(pair, pairOriginal);
    }

    function testSyncRegression(uint96 _reserve0, uint96 _reserve1, uint72 _amount0In, uint72 _amount1In) public {
        _reserve0 = uint96(bound(_reserve0, 10000e18, type(uint96).max));
        _reserve1 = uint96(bound(_reserve1, 10000e18, type(uint96).max));
        _amount0In = uint72(bound(_amount0In, 0.001e18, type(uint72).max));
        _amount1In = uint72(bound(_amount1In, 0.001e18, type(uint72).max));

        vm.assume(_amount1In > 0.001e18);

        _addLiquidity(address(pair), _reserve0, _reserve1, user3);
        _addLiquidity(address(pairOriginal), _reserve0, _reserve1, user3);

        _assertPairs(pair, pairOriginal);

        token0.mint(address(pair), _amount0In);
        token1.mint(address(pair), _amount1In);
        token0.mint(address(pairOriginal), _amount0In);
        token1.mint(address(pairOriginal), _amount1In);

        _assertPairs(pair, pairOriginal);

        pair.sync();
        pairOriginal.sync();

        _assertPairs(pair, pairOriginal);
    }

    function testSwapWithFees(
        uint96 _reserve0,
        uint96 _reserve1,
        uint72 _amount0In,
        uint72 _amount1In,
        uint256 _hijackAmount
    ) public {
        _reserve0 = uint96(bound(_reserve0, 10000e18, type(uint96).max));
        _reserve1 = uint96(bound(_reserve1, 10000e18, type(uint96).max));
        _amount0In = uint72(bound(_amount0In, 0.001e18, type(uint72).max));
        _amount1In = uint72(bound(_amount1In, 0.001e18, type(uint72).max));
        _hijackAmount = uint72(bound(_hijackAmount, 0.001e18, type(uint72).max));
        vm.assume(_amount0In > _hijackAmount);

        _addLiquidity(address(pairWithFees), _reserve0, _reserve1, user3);
        _addLiquidity(address(pairOriginal), _reserve0, _reserve1, user3);

        _assertPairs(pairWithFees, pairOriginal);

        assertEq(token0.balanceOf(user1), 0);
        assertEq(token1.balanceOf(user1), 0);

        (, address beneficiary, uint256 royalties, address protocolBeneficiary, uint256 protocolBeneficiaryFee) =
            factory.getFeesAndRecipients(address(pairWithFees));

        assertEq(beneficiary, royaltiesBeneficiary);
        assertEq(royalties, royaltiesFee);
        assertEq(token0.balanceOf(beneficiary), 0);
        uint256 royaltiesAmount = _amount0In * royalties / 10000;

        assertEq(protocolBeneficiary, protocolFeeBeneficiary);
        assertEq(protocolBeneficiaryFee, protocolFee);
        assertEq(token0.balanceOf(protocolBeneficiary), 0);
        uint256 protocolFeeAmount = _amount0In * protocolBeneficiaryFee / 10000;

        uint256 amount1Out = _swap(address(pairWithFees), _amount0In, _hijackAmount, user1);
        assertEq(token0.balanceOf(user1), 0);
        assertEq(token1.balanceOf(user1), amount1Out);
        assertEq(token0.balanceOf(beneficiary), royaltiesAmount);
        assertEq(token0.balanceOf(protocolBeneficiary), protocolFeeAmount);
        assertEq(token1.balanceOf(beneficiary), _hijackAmount * royalties / 10000);
        assertEq(token1.balanceOf(protocolBeneficiary), _hijackAmount * protocolBeneficiaryFee / 10000);

        assertEq(token0.balanceOf(user2), 0);
        assertEq(token1.balanceOf(user2), 0);

        uint256 amount1OutOrg = _swap(address(pairOriginal), _amount0In, 0, user2);
        assertEq(token0.balanceOf(user2), 0);
        assertEq(token1.balanceOf(user2), amount1OutOrg);

        uint256 maxPercentDelta = (royaltiesFee + protocolFee + 1) * 1e18 / 10000;
        assertApproxEqRel(amount1Out, amount1OutOrg, maxPercentDelta);
    }
}
