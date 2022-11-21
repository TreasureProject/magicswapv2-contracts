// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

contract UniswapV2Factory is IUniswapV2Factory, Ownable2Step {
    /// @dev Fee is denominated in basis points so 5000 / 10000 = 50%
    uint256 public constant MAX_FEE = 5000;

    address public protocolFeeBeneficiary;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    Fees public defaultFees;
    mapping(address => Fees) public pairFees;

    constructor(
        uint256 _defaultProtocolFee,
        uint256 _defaultLpFee,
        address _protocolFeeBeneficiary
    ) {
        Fees memory startFees = Fees({
            royaltiesBeneficiary: address(0),
            royaltiesFee: 0,
            protocolFee: _defaultProtocolFee,
            lpFee: _defaultLpFee
        });

        setDefaultFees(startFees);
        setProtocolFeeBeneficiary(_protocolFeeBeneficiary);
    }

    /// @inheritdoc IUniswapV2Factory
    function getTotalFee(address _pair) public view returns (uint256) {
        (uint256 lpFee, uint256 royaltiesFee, uint256 protocolFee) = _getFees(_pair);
        return lpFee + royaltiesFee + protocolFee;
    }

    /// @inheritdoc IUniswapV2Factory
    function getFees(address _pair)
        public
        view
        returns (uint256 lpFee, uint256 royaltiesFee, uint256 protocolFee)
    {
        return _getFees(_pair);
    }

    /// @inheritdoc IUniswapV2Factory
    function getFeesAndRecipients(address _pair) public view returns (
        uint256 lpFee,
        address royaltiesBeneficiary,
        uint256 royaltiesFee,
        address protocolBeneficiary,
        uint256 protocolFee
    ) {
        (lpFee, royaltiesFee, protocolFee) = _getFees(_pair);

        royaltiesBeneficiary = pairFees[_pair].royaltiesBeneficiary;
        protocolBeneficiary = protocolFeeBeneficiary;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'MagicswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'MagicswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'MagicswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /// @inheritdoc IUniswapV2Factory
    function setDefaultFees(Fees memory _fees) public onlyOwner {
        require(_fees.protocolFee <= MAX_FEE, 'MagicswapV2: protocolFee > MAX_FEE');
        require(_fees.lpFee <= MAX_FEE, 'MagicswapV2: lpFee > MAX_FEE');
        require(_fees.protocolFee + _fees.lpFee <= MAX_FEE, 'MagicswapV2: protocolFee + lpFee > MAX_FEE');
        defaultFees = _fees;
    }

    /// @inheritdoc IUniswapV2Factory
    function setLpFee(address _pair, uint256 _lpFee) external onlyOwner {
        require(_lpFee <= MAX_FEE, 'MagicswapV2: _lpFee > MAX_FEE');
        pairFees[_pair].lpFee = _lpFee;
    }

    /// @inheritdoc IUniswapV2Factory
    function setRoyaltiesFee(address _pair, address _beneficiary, uint256 _royaltiesFee) external onlyOwner {
        require(_royaltiesFee <= MAX_FEE, 'MagicswapV2: _royaltiesFee > MAX_FEE');
        pairFees[_pair].royaltiesBeneficiary = _beneficiary;
        pairFees[_pair].royaltiesFee = _royaltiesFee;
    }

    /// @inheritdoc IUniswapV2Factory
    function setProtocolFee(address _pair, uint256 _protocolFee) external onlyOwner {
        require(_protocolFee <= MAX_FEE, 'MagicswapV2: _protocolFee > MAX_FEE');
        pairFees[_pair].protocolFee = _protocolFee;
    }

    /// @inheritdoc IUniswapV2Factory
    function setProtocolFeeBeneficiary(address _beneficiary) public onlyOwner {
        require(_beneficiary != address(0), 'MagicswapV2: BENEFICIARY');
        protocolFeeBeneficiary = _beneficiary;
    }

    function _getLpFee(address _pair) internal view returns (uint256 lpFee) {
        lpFee = pairFees[_pair].lpFee;

        if (lpFee == 0) lpFee = defaultFees.lpFee;
    }

    function _getRoyaltiesFee(address _pair) internal view returns (uint256 royaltiesFee) {
        return pairFees[_pair].royaltiesFee;
    }

    function _getProtocolFee(address _pair) internal view returns (uint256 protocolFee) {
        protocolFee = pairFees[_pair].protocolFee;

        if (protocolFee == 0) protocolFee = defaultFees.protocolFee;
    }

    function _getFees(address _pair)
        internal
        view
        returns (uint256 lpFee, uint256 royaltiesFee, uint256 protocolFee)
    {
        lpFee = _getLpFee(_pair);
        /// lpFee should never be above MAX_FEE but never too safe.
        /// If lpFee is set to MAX_FEE then we know there's no more space for other fees
        if (lpFee >= MAX_FEE) {
            return (MAX_FEE, 0, 0);
        }

        royaltiesFee = _getRoyaltiesFee(_pair);
        /// if royaltiesFee + lpFee is greater than MAX_FEE, then decrease royaltiesFee
        /// and return as we know there's no more space for other fees
        if (royaltiesFee >= MAX_FEE - lpFee) {
            return (lpFee, MAX_FEE - lpFee, 0);
        }

        protocolFee = _getProtocolFee(_pair);
        /// if protocolFee + royaltiesFee + lpFee is greater than MAX_FEE, then decrease protocolFee
        if (protocolFee > MAX_FEE - lpFee - royaltiesFee) {
            protocolFee = MAX_FEE - lpFee - royaltiesFee;
        }
    }
}
