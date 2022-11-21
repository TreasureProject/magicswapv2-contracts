// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

interface IUniswapV2Factory {
    struct Fees {
        address royaltiesBeneficiary;
        /// @dev in basis point, denominated by 10000
        uint256 royaltiesFee;
        /// @dev in basis point, denominated by 10000
        uint256 protocolFee;
        /// @dev in basis point, denominated by 10000
        uint256 lpFee;
    }

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function getTotalFee(address pair) external view returns (uint256 totalFee);
    function getFees(address _pair)
        external
        view
        returns (uint256 lpFee, uint256 royaltiesFee, uint256 protocolFee);
    function getFeesAndRecipients(address _pair) external view returns (
        uint256 lpFee,
        address royaltiesBeneficiary,
        uint256 royaltiesFee,
        address protocolBeneficiary,
        uint256 protocolFee
    );
    function protocolFeeBeneficiary() external view returns (address protocolFeeBeneficiary);

    function pairFees(address pair) external view returns (address, uint256, uint256, uint256);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setDefaultFees(Fees memory fees) external;
    function setRoyaltiesFee(address pair, address beneficiary, uint256 royaltiesFee) external;
    function setProtocolFee(address pair, uint256 protocolFee) external;
    function setLpFee(address pair, uint256 lpFee) external;
}
