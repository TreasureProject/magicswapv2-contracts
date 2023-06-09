// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import  "../../CreatorWhitelistRegistry/ICreatorWhitelistRegistry.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./UniswapV2Pair.sol";

contract UniswapV2Factory is IUniswapV2Factory, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Fee is denominated in basis points so 5000 / 10000 = 50%
    uint256 public constant MAX_FEE = 5000;

    ICreatorWhitelistRegistry creatorWhitelistRegistry;

    address public protocolFeeBeneficiary;

    mapping(address => mapping(address => address)) public getPair;
    EnumerableSet.AddressSet private _allPairs;

    DefaultFees public defaultFees;
    mapping(address => Fees) public pairFees;

    constructor(uint256 _defaultProtocolFee, uint256 _defaultLpFee, address _protocolFeeBeneficiary) {
        DefaultFees memory startFees = DefaultFees({protocolFee: _defaultProtocolFee, lpFee: _defaultLpFee});

        setDefaultFees(startFees);
        setProtocolFeeBeneficiary(_protocolFeeBeneficiary);
    }

    /// @dev Sets the creator whitelist registry address.
    /// @param _creatorWhitelistRegistryAddress The address of the registry.
    function setCreatorWhitelistRegistryAddress(address _creatorWhitelistRegistryAddress) external onlyOwner{
        creatorWhitelistRegistry = ICreatorWhitelistRegistry(_creatorWhitelistRegistryAddress);
    }

    /// @inheritdoc IUniswapV2Factory
    function getTotalFee(address _pair) public view returns (uint256) {
        (uint256 lpFee, uint256 royaltiesFee, uint256 protocolFee) = _getFees(_pair);
        return lpFee + royaltiesFee + protocolFee;
    }

    /// @inheritdoc IUniswapV2Factory
    function getFees(address _pair) public view returns (uint256 lpFee, uint256 royaltiesFee, uint256 protocolFee) {
        return _getFees(_pair);
    }

    /// @inheritdoc IUniswapV2Factory
    function getFeesAndRecipients(address _pair)
        public
        view
        returns (
            uint256 lpFee,
            address royaltiesBeneficiary,
            uint256 royaltiesFee,
            address protocolBeneficiary,
            uint256 protocolFee
        )
    {
        (lpFee, royaltiesFee, protocolFee) = _getFees(_pair);

        royaltiesBeneficiary = pairFees[_pair].royaltiesBeneficiary;
        protocolBeneficiary = protocolFeeBeneficiary;
    }

    function allPairs() external view returns (address[] memory) {
        return _allPairs.values();
    }

    function allPairs(uint256 _index) external view returns (address) {
        return _allPairs.at(_index);
    }

    function allPairsLength() external view returns (uint256) {
        return _allPairs.length();
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (creatorWhitelistRegistry.useCreatorWhitelistRegistry()){
            require(creatorWhitelistRegistry.isCreator(msg.sender), "Msg sender is not approved creator!");
        }

        require(tokenA != tokenB, "MagicswapV2: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "MagicswapV2: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "MagicswapV2: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        _allPairs.add(pair);
        emit PairCreated(token0, token1, pair, _allPairs.length());
    }

    /// @inheritdoc IUniswapV2Factory
    function setDefaultFees(DefaultFees memory _fees) public onlyOwner {
        require(_fees.protocolFee <= MAX_FEE, "MagicswapV2: protocolFee > MAX_FEE");
        require(_fees.lpFee <= MAX_FEE, "MagicswapV2: lpFee > MAX_FEE");
        require(_fees.protocolFee + _fees.lpFee <= MAX_FEE, "MagicswapV2: protocolFee + lpFee > MAX_FEE");

        defaultFees = _fees;

        emit DefaultFeesSet(_fees);
    }

    /// @inheritdoc IUniswapV2Factory
    function setLpFee(address _pair, uint256 _lpFee, bool _overrideFee) external onlyOwner {
        require(_lpFee <= MAX_FEE, "MagicswapV2: _lpFee > MAX_FEE");
        require(_allPairs.contains(_pair), "MagicswapV2: _pair invalid");

        pairFees[_pair].lpFee = _lpFee;
        pairFees[_pair].lpFeeOverride = _overrideFee;

        emit LpFeesSet(_pair, _lpFee, _overrideFee);
    }

    /// @inheritdoc IUniswapV2Factory
    function setRoyaltiesFee(address _pair, address _beneficiary, uint256 _royaltiesFee) external onlyOwner {
        require(_royaltiesFee <= MAX_FEE, "MagicswapV2: _royaltiesFee > MAX_FEE");
        require(_allPairs.contains(_pair), "MagicswapV2: _pair invalid");
        require(_beneficiary != address(0), "MagicswapV2: _beneficiary invalid");

        pairFees[_pair].royaltiesBeneficiary = _beneficiary;
        pairFees[_pair].royaltiesFee = _royaltiesFee;

        emit RoyaltiesFeesSet(_pair, _beneficiary, _royaltiesFee);
    }

    /// @inheritdoc IUniswapV2Factory
    function setProtocolFee(address _pair, uint256 _protocolFee, bool _overrideFee) external onlyOwner {
        require(_protocolFee <= MAX_FEE, "MagicswapV2: _protocolFee > MAX_FEE");
        require(_allPairs.contains(_pair), "MagicswapV2: _pair invalid");

        pairFees[_pair].protocolFee = _protocolFee;
        pairFees[_pair].protocolFeeOverride = _overrideFee;

        emit ProtocolFeesSet(_pair, _protocolFee, _overrideFee);
    }

    /// @inheritdoc IUniswapV2Factory
    function setProtocolFeeBeneficiary(address _beneficiary) public onlyOwner {
        require(_beneficiary != address(0), "MagicswapV2: BENEFICIARY");
        protocolFeeBeneficiary = _beneficiary;

        emit ProtocolFeeBeneficiarySet(_beneficiary);
    }

    function _getLpFee(address _pair) internal view returns (uint256 lpFee) {
        if (pairFees[_pair].lpFeeOverride) {
            return pairFees[_pair].lpFee;
        } else {
            return defaultFees.lpFee;
        }
    }

    function _getRoyaltiesFee(address _pair) internal view returns (uint256 royaltiesFee) {
        return pairFees[_pair].royaltiesFee;
    }

    function _getProtocolFee(address _pair) internal view returns (uint256 protocolFee) {
        if (pairFees[_pair].protocolFeeOverride) {
            return pairFees[_pair].protocolFee;
        } else {
            return defaultFees.protocolFee;
        }
    }

    function _getFees(address _pair) internal view returns (uint256 lpFee, uint256 royaltiesFee, uint256 protocolFee) {
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
