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

    /// @dev NOTICE: If malicious owner sets PROTOCOL_FEE and LP_FEE to 0, then ROYALTIES_FEE to MAX_FEE
    /// and then sets defaultFees to MAX_FEE, it's possible to arrive at total fees being equal to
    /// MAX_FEE + MAX_FEE even though MAX_FEE should be the limit.
    modifier checkMaxFee(address _pair) {
        _;

        require(getTotalFee(_pair) <= MAX_FEE, 'MagicswapV2: MAX_FEE');
    }

    constructor(Fees memory _fees, address _protocolFeeBeneficiary) {
        setDefaultFees(_fees);
        setProtocolFeeBeneficiary(_protocolFeeBeneficiary);
    }

    function getTotalFee(address _pair) public view returns (uint256 totalFee) {
        (, uint256 royaltiesFee) = getRoyaltiesFee(_pair);
        totalFee = royaltiesFee + getProtocolFee(_pair) + getLpFee(_pair);
    }

    function getFeesAndRecipients(address _pair) public view returns (
        uint256 royaltiesFee,
        uint256 protocolFee,
        uint256 lpFee,
        address royaltiesBeneficiary,
        address protocolBeneficiary
    ) {
        (royaltiesBeneficiary, royaltiesFee) = getRoyaltiesFee(_pair);
        protocolFee = getProtocolFee(_pair);
        lpFee = getLpFee(_pair);
        protocolBeneficiary = protocolFeeBeneficiary;
    }

    function getRoyaltiesFee(address _pair) public view returns (address beneficiary, uint256 royaltiesFee) {
        return (pairFees[_pair].royaltiesBeneficiary, pairFees[_pair].royaltiesFee);
    }

    function getProtocolFee(address _pair) public view returns (uint256 protocolFee) {
        protocolFee = pairFees[_pair].protocolFee;

        if (protocolFee == 0) protocolFee = defaultFees.protocolFee;
    }

    function getLpFee(address _pair) public view returns (uint256 lpFee){
        lpFee = pairFees[_pair].lpFee;

        if (lpFee == 0) lpFee = defaultFees.lpFee;
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

    function setDefaultFees(Fees memory _fees) public onlyOwner {
        require(_fees.protocolFee <= MAX_FEE, 'MagicswapV2: MAX_FEE');
        require(_fees.lpFee <= MAX_FEE, 'MagicswapV2: MAX_FEE');
        require(_fees.protocolFee + _fees.lpFee <= MAX_FEE, 'MagicswapV2: MAX_FEE');
        defaultFees = _fees;
    }

    function setRoyaltiesFee(address _pair, address _beneficiary, uint256 _royaltiesFee)
        external
        checkMaxFee(_pair)
        onlyOwner
    {
        require(_royaltiesFee <= MAX_FEE, 'MagicswapV2: MAX_FEE');
        pairFees[_pair].royaltiesBeneficiary = _beneficiary;
        pairFees[_pair].royaltiesFee = _royaltiesFee;
    }

    function setProtocolFee(address _pair, uint256 _protocolFee) external checkMaxFee(_pair) onlyOwner {
        require(_protocolFee <= MAX_FEE, 'MagicswapV2: MAX_FEE');
        pairFees[_pair].protocolFee = _protocolFee;
    }

    function setProtocolFeeBeneficiary(address _beneficiary) public onlyOwner {
        require(_beneficiary != address(0), 'MagicswapV2: BENEFICIARY');
        protocolFeeBeneficiary = _beneficiary;
    }

    function setLpFee(address _pair, uint256 _lpFee) external checkMaxFee(_pair) onlyOwner {
        require(_lpFee <= MAX_FEE, 'MagicswapV2: MAX_FEE');
        pairFees[_pair].lpFee = _lpFee;
    }
}
