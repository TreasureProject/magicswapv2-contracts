// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "lib/ERC20Mintable.sol";

import "../UniswapV2Factory.sol";
import "../../periphery/libraries/UniswapV2Library.sol";

contract UniswapV2FactoryTest is Test {
    UniswapV2Factory factory;

    address pool1;
    address hacker = address(10000004);
    address owner = address(10000005);

    address tokenA = address(10000006);
    address tokenB = address(10000007);

    address protocolFeeBeneficiary = address(10000005);

    uint256 tooBigFee;
    uint256 MAX_FEE;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );
    event DefaultFeesSet(IUniswapV2Factory.DefaultFees fees);
    event LpFeesSet(address indexed pair, uint256 lpFee, bool overrideFee);
    event RoyaltiesFeesSet(
        address indexed pair,
        address beneficiary,
        uint256 royaltiesFee
    );
    event ProtocolFeesSet(
        address indexed pair,
        uint256 protocolFee,
        bool overrideFee
    );
    event ProtocolFeeBeneficiarySet(address beneficiary);

    function setUp() public {
        vm.prank(owner);
        factory = new UniswapV2Factory(0, 0, protocolFeeBeneficiary);

        MAX_FEE = factory.MAX_FEE();
        tooBigFee = MAX_FEE + 1;

        pool1 = _createPair(tokenA, tokenB);
    }

    function _assertFees(
        address _expectedPool,
        address _expectedRoyaltiesBeneficiary,
        uint256 _expectedRoyaltiesFee,
        uint256 _expectedProtocolFee,
        uint256 _expectedLpFee,
        address _expectedProtocolFeeBeneficiary
    ) public {
        (
            uint256 lpFee,
            address royaltiesBeneficiary,
            uint256 royaltiesFee,
            address protocolBeneficiary,
            uint256 protocolFee
        ) = factory.getFeesAndRecipients(_expectedPool);

        assertEq(lpFee, _expectedLpFee);
        assertEq(royaltiesBeneficiary, _expectedRoyaltiesBeneficiary);
        assertEq(royaltiesFee, _expectedRoyaltiesFee);
        assertEq(protocolBeneficiary, _expectedProtocolFeeBeneficiary);
        assertEq(protocolFee, _expectedProtocolFee);
    }

    function _createPair(
        address _tokenA,
        address _tokenB
    ) public returns (address pair) {
        vm.mockCall(
            _tokenA,
            abi.encodeCall(ERC20.decimals, ()),
            abi.encode(18)
        );
        vm.mockCall(
            _tokenB,
            abi.encodeCall(ERC20.decimals, ()),
            abi.encode(18)
        );

        pair = factory.createPair(_tokenA, _tokenB);
    }

    function testSetDefaultFees(uint256 _lpFee, uint256 _protocolFee) public {
        vm.assume(_lpFee <= MAX_FEE);
        vm.assume(_protocolFee <= MAX_FEE);
        vm.assume(_protocolFee + _lpFee <= MAX_FEE);

        (uint256 protocolFee, uint256 lpFee) = factory.defaultFees();

        assertEq(protocolFee, 0);
        assertEq(lpFee, 0);

        _assertFees(pool1, address(0), 0, 0, 0, protocolFeeBeneficiary);

        IUniswapV2Factory.DefaultFees memory fees = IUniswapV2Factory
            .DefaultFees({protocolFee: _protocolFee, lpFee: _lpFee});

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setDefaultFees(fees);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DefaultFeesSet(fees);
        factory.setDefaultFees(fees);

        (protocolFee, lpFee) = factory.defaultFees();

        assertEq(protocolFee, _protocolFee);
        assertEq(lpFee, _lpFee);

        _assertFees(
            pool1,
            address(0),
            0,
            _protocolFee,
            _lpFee,
            protocolFeeBeneficiary
        );

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: protocolFee > MAX_FEE");
        factory.setDefaultFees(
            IUniswapV2Factory.DefaultFees({
                protocolFee: tooBigFee,
                lpFee: _lpFee
            })
        );

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: lpFee > MAX_FEE");
        factory.setDefaultFees(
            IUniswapV2Factory.DefaultFees({
                protocolFee: _protocolFee,
                lpFee: tooBigFee
            })
        );

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: protocolFee + lpFee > MAX_FEE");
        factory.setDefaultFees(
            IUniswapV2Factory.DefaultFees({
                protocolFee: tooBigFee / 2 + 1,
                lpFee: tooBigFee / 2
            })
        );
    }

    function testSetLpFee(
        address _pair,
        uint256 _lpFee,
        address _tokenA,
        address _tokenB
    ) public {
        vm.assume(_lpFee <= MAX_FEE);

        vm.assume(_pair != pool1);
        vm.assume(_tokenA != address(0));
        vm.assume(_tokenB != address(0));
        vm.assume(_tokenA != _tokenB);

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setLpFee(_pair, _lpFee, true);

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: _pair invalid");
        factory.setLpFee(_pair, _lpFee, true);

        _pair = _createPair(_tokenA, _tokenB);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit LpFeesSet(_pair, _lpFee, true);
        factory.setLpFee(_pair, _lpFee, true);

        (
            address royaltiesBeneficiary,
            uint256 royaltiesFee,
            uint256 protocolFee,
            uint256 lpFee,
            bool protocolFeeOverride,
            bool lpFeeOverride
        ) = factory.pairFees(_pair);

        assertEq(royaltiesBeneficiary, address(0));
        assertEq(royaltiesFee, 0);
        assertEq(protocolFee, 0);
        assertEq(lpFee, _lpFee);
        assertFalse(protocolFeeOverride);
        assertTrue(lpFeeOverride);

        _assertFees(_pair, address(0), 0, 0, _lpFee, protocolFeeBeneficiary);

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: _lpFee > MAX_FEE");
        factory.setLpFee(_pair, tooBigFee, true);
    }

    function testSetRoyaltiesFee(
        address _pair,
        address _royaltiesBeneficiary,
        uint256 _royaltiesFee,
        address _tokenA,
        address _tokenB
    ) public {
        vm.assume(_royaltiesFee <= MAX_FEE);

        vm.assume(_pair != pool1);
        vm.assume(_tokenA != address(0));
        vm.assume(_tokenB != address(0));
        vm.assume(_tokenA != _tokenB);

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setRoyaltiesFee(_pair, _royaltiesBeneficiary, _royaltiesFee);

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: _pair invalid");
        factory.setRoyaltiesFee(_pair, _royaltiesBeneficiary, _royaltiesFee);

        _pair = _createPair(_tokenA, _tokenB);

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: _beneficiary invalid");
        factory.setRoyaltiesFee(_pair, address(0), _royaltiesFee);

        vm.assume(_royaltiesBeneficiary != address(0));

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit RoyaltiesFeesSet(_pair, _royaltiesBeneficiary, _royaltiesFee);
        factory.setRoyaltiesFee(_pair, _royaltiesBeneficiary, _royaltiesFee);

        (
            address royaltiesBeneficiary,
            uint256 royaltiesFee,
            uint256 protocolFee,
            uint256 lpFee,
            bool protocolFeeOverride,
            bool lpFeeOverride
        ) = factory.pairFees(_pair);

        assertEq(royaltiesBeneficiary, _royaltiesBeneficiary);
        assertEq(royaltiesFee, _royaltiesFee);
        assertEq(protocolFee, 0);
        assertEq(lpFee, 0);
        assertFalse(protocolFeeOverride);
        assertFalse(lpFeeOverride);

        _assertFees(
            _pair,
            _royaltiesBeneficiary,
            _royaltiesFee,
            0,
            0,
            protocolFeeBeneficiary
        );

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: _royaltiesFee > MAX_FEE");
        factory.setRoyaltiesFee(_pair, _royaltiesBeneficiary, tooBigFee);
    }

    function testSetProtocolFee(
        address _pair,
        uint256 _protocolFee,
        address _tokenA,
        address _tokenB
    ) public {
        vm.assume(_protocolFee <= MAX_FEE);
        vm.assume(_pair != pool1);

        vm.assume(_tokenA != address(0));
        vm.assume(_tokenB != address(0));
        vm.assume(_tokenA != _tokenB);

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setProtocolFee(_pair, _protocolFee, true);

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: _pair invalid");
        factory.setProtocolFee(_pair, _protocolFee, true);

        _pair = _createPair(_tokenA, _tokenB);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ProtocolFeesSet(_pair, _protocolFee, true);
        factory.setProtocolFee(_pair, _protocolFee, true);

        (
            address royaltiesBeneficiary,
            uint256 royaltiesFee,
            uint256 protocolFee,
            uint256 lpFee,
            bool protocolFeeOverride,
            bool lpFeeOverride
        ) = factory.pairFees(_pair);

        assertEq(royaltiesBeneficiary, address(0));
        assertEq(royaltiesFee, 0);
        assertEq(protocolFee, _protocolFee);
        assertEq(lpFee, 0);
        assertTrue(protocolFeeOverride);
        assertFalse(lpFeeOverride);

        _assertFees(
            _pair,
            address(0),
            0,
            _protocolFee,
            0,
            protocolFeeBeneficiary
        );

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: _protocolFee > MAX_FEE");
        factory.setProtocolFee(_pair, tooBigFee, true);
    }

    function testSetProtocolFeeBeneficiary(address _beneficiary) public {
        vm.assume(_beneficiary != address(0));

        vm.prank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setProtocolFeeBeneficiary(_beneficiary);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ProtocolFeeBeneficiarySet(_beneficiary);
        factory.setProtocolFeeBeneficiary(_beneficiary);

        assertEq(factory.protocolFeeBeneficiary(), _beneficiary);
        _assertFees(pool1, address(0), 0, 0, 0, _beneficiary);

        vm.prank(owner);
        vm.expectRevert("MagicswapV2: BENEFICIARY");
        factory.setProtocolFeeBeneficiary(address(0));
    }

    function testGetFees(
        uint256 _lpFee,
        uint256 _royaltiesFee,
        uint256 _protocolFee
    ) public {
        vm.assume(_lpFee <= MAX_FEE);
        vm.assume(_royaltiesFee <= MAX_FEE);
        vm.assume(_protocolFee <= MAX_FEE);

        vm.startPrank(owner);
        factory.setLpFee(pool1, _lpFee, true);
        factory.setRoyaltiesFee(pool1, owner, _royaltiesFee);
        factory.setProtocolFee(pool1, _protocolFee, true);
        vm.stopPrank();

        (uint256 lpFee, uint256 royaltiesFee, uint256 protocolFee) = factory
            .getFees(pool1);
        uint256 totalFee = lpFee + royaltiesFee + protocolFee;

        assertEq(lpFee, _lpFee);

        /// logic below should check that:
        /// - totalFee is never above MAX_FEE
        /// - if _lpFee + _royaltiesFee + _protocolFee > MAX_FEE
        ///   then we fill totalFee with fees in following priority:
        ///   1. lpFee
        ///   2. royaltiesFee
        ///   3. protocolFee
        ///   until we get to MAX_FEE

        if (_lpFee < MAX_FEE) {
            if (_lpFee + _royaltiesFee < MAX_FEE) {
                assertEq(royaltiesFee, _royaltiesFee);

                if (_lpFee + _royaltiesFee + _protocolFee <= MAX_FEE) {
                    assertEq(protocolFee, _protocolFee);
                    assertEq(
                        _lpFee + _royaltiesFee + _protocolFee,
                        factory.getTotalFee(pool1)
                    );
                } else {
                    assertEq(protocolFee, MAX_FEE - _lpFee - _royaltiesFee);
                }
            } else {
                assertEq(royaltiesFee, MAX_FEE - _lpFee);
                assertEq(protocolFee, 0);
            }
        } else {
            assertEq(royaltiesFee, 0);
            assertEq(protocolFee, 0);
        }

        assertEq(totalFee, factory.getTotalFee(pool1));
        assertTrue(totalFee <= MAX_FEE);
    }

    function testCreatePair(address _tokenA, address _tokenB) public {
        vm.assume(_tokenA != address(0));
        vm.assume(_tokenB != address(0));
        vm.assume(_tokenA != _tokenB);

        vm.mockCall(
            _tokenA,
            abi.encodeCall(ERC20.decimals, ()),
            abi.encode(18)
        );
        vm.mockCall(
            _tokenB,
            abi.encodeCall(ERC20.decimals, ()),
            abi.encode(18)
        );

        (address token0, address token1) = UniswapV2Library.sortTokens(
            _tokenA,
            _tokenB
        );
        address expectedPair = UniswapV2Library.pairFor(
            address(factory),
            _tokenA,
            _tokenB
        );

        vm.expectEmit(true, true, true, true);
        emit PairCreated(token0, token1, expectedPair, 2);
        address pair = factory.createPair(_tokenA, _tokenB);

        assertEq(pair, expectedPair);
        assertEq(factory.getPair(_tokenA, _tokenB), pair);
        assertEq(factory.getPair(_tokenB, _tokenA), pair);
        assertEq(factory.allPairs(1), pair);
        assertEq(factory.allPairsLength(), 2);

        address[] memory allPairs = factory.allPairs();
        assertEq(allPairs[0], pool1);
        assertEq(allPairs[1], pair);
    }
}
