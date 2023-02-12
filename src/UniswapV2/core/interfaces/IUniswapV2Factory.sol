// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IUniswapV2Factory {
    struct DefaultFees {
        /// @dev in basis point, denominated by 10000
        uint256 protocolFee;
        /// @dev in basis point, denominated by 10000
        uint256 lpFee;
    }

    struct Fees {
        address royaltiesBeneficiary;
        /// @dev in basis point, denominated by 10000
        uint256 royaltiesFee;
        /// @dev in basis point, denominated by 10000
        uint256 protocolFee;
        /// @dev in basis point, denominated by 10000
        uint256 lpFee;
        /// @dev if true, Fees.protocolFee is used even if set to 0
        bool protocolFeeOverride;
        /// @dev if true, Fees.lpFee is used even if set to 0
        bool lpFeeOverride;
    }

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event DefaultFeesSet(DefaultFees fees);
    event LpFeesSet(address indexed pair, uint256 lpFee, bool overrideFee);
    event RoyaltiesFeesSet(address indexed pair, address beneficiary, uint256 royaltiesFee);
    event ProtocolFeesSet(address indexed pair, uint256 protocolFee, bool overrideFee);
    event ProtocolFeeBeneficiarySet(address beneficiary);

    /// @notice Returns total fee pair charges
    /// @dev Fee is capped at MAX_FEE
    /// @param pair address of pair for which to calculate fees
    /// @return totalFee total fee amount denominated in basis points
    function getTotalFee(address pair) external view returns (uint256 totalFee);

    /// @notice Returns all fees for pair
    /// @return lpFee fee changed by liquidity providers, denominated in basis points
    /// @return royaltiesFee royalties paid to NFT creators, denominated in basis points
    /// @return protocolFee fee paid to the protocol, denominated in basis points
    function getFees(address _pair) external view returns (uint256 lpFee, uint256 royaltiesFee, uint256 protocolFee);

    /// @notice Returns all fees for pair and beneficiaries
    /// @dev Fees are capped by MAX_FEE, however it is possible for a malicious owner
    ///      of this contract to do a combination of transactions to achive fees above MAX_FEE.
    ///      In case such combination of transactions is executed, by accident or otherwise,
    ///      fees are allocatied by priority:
    ///      1. lp fee
    ///      2. royalties
    ///      3. protocol fee
    ///      If MAX_FEE == 5000, lpFee == 500, royaltiesFee == 4000 and protocolFee == 5000 then
    ///      effective fees will be allocated acording to the fee priority up to MAX_FEE value.
    ///      In this example: lpFee == 500, royaltiesFee == 4000 and protocolFee == 500.
    /// @param pair address of pair for which to calculate fees and beneficiaries
    /// @return lpFee fee changed by liquidity providers, denominated in basis points
    /// @return royaltiesBeneficiary address that gets royalties
    /// @return royaltiesFee royalties paid to NFT creators, denominated in basis points
    /// @return protocolBeneficiary address that gets protocol fees
    /// @return protocolFee fee paid to the protocol, denominated in basis points
    function getFeesAndRecipients(address pair)
        external
        view
        returns (
            uint256 lpFee,
            address royaltiesBeneficiary,
            uint256 royaltiesFee,
            address protocolBeneficiary,
            uint256 protocolFee
        );

    /// @return protocolFeeBeneficiary address that gets protocol fees
    function protocolFeeBeneficiary() external view returns (address protocolFeeBeneficiary);

    /// @notice Internal mapping to store fees for pair. It is exposed for advanced integrations
    ///         and in most cases contracts should use fee getters.
    function pairFees(address pair) external view returns (address, uint256, uint256, uint256, bool, bool);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs() external view returns (address[] memory pairs);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    /// @notice Sets default fees for all pairs
    /// @param fees struct with default fees
    function setDefaultFees(DefaultFees memory fees) external;

    /// @notice Sets royalties fee and beneficiary for pair
    /// @param pair address of pair for which to set fee
    /// @param beneficiary address that gets royalties
    /// @param royaltiesFee amount of royalties fee denominated in basis points
    function setRoyaltiesFee(address pair, address beneficiary, uint256 royaltiesFee) external;

    /// @notice Sets protocol fee for pair
    /// @param pair address of pair for which to set fee
    /// @param protocolFee amount of protocol fee denominated in basis points
    /// @param overrideFee if true, fee will be overriden even if set to 0
    function setProtocolFee(address pair, uint256 protocolFee, bool overrideFee) external;

    /// @notice Sets lp fee for pair
    /// @param pair address of pair for which to set fee
    /// @param lpFee amount of lp fee denominated in basis points
    /// @param overrideFee if true, fee will be overriden even if set to 0
    function setLpFee(address pair, uint256 lpFee, bool overrideFee) external;

    /// @notice Sets protocol fee beneficiary
    /// @param _beneficiary address that gets protocol fees
    function setProtocolFeeBeneficiary(address _beneficiary) external;
}
