// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "./INftVault.sol";

/// @title Vault factory contract
interface INftVaultFactory {
    /// @notice Emitted when new vault is deployed
    /// @param name vault's name
    /// @param symbol vault's name
    /// @param vault vault's address as INftVault
    /// @param vaultId vault's index in `vaults` AddressSet
    /// @param collections configuration used for vault creation
    /// @param creator address of vault creator
    event VaultCreated(
        string name,
        string symbol,
        INftVault vault,
        uint256 vaultId,
        INftVault.CollectionData[] collections,
        address creator
    );

    /// @dev Vault does not exist
    error VaultDoesNotExist();

    /// @notice Get vault by its config hash
    /// @param _hash vault's config hash
    /// @return vault address
    function vaultHashMap(bytes32 _hash) external view returns (INftVault vault);

    /// @return all deployed vaults
    function getAllVaults() external view returns (address[] memory);

    /// @notice Get vault by its EnumerableSet vaultId
    /// @param _i vaultId
    /// @return vault address
    function getVaultAt(uint256 _i) external view returns (address);

    /// @return length of vault's EnumerableSet
    function getVaultLength() external view returns (uint256);

    /// @notice Returns true if vault has been deployed by factory
    /// @param _vault address
    function isVault(address _vault) external view returns (bool);

    /// @notice Get vault by it's config
    /// @param _collections vault's config
    /// @return vault address
    function getVault(INftVault.CollectionData[] memory _collections) external view returns (INftVault vault);

    /// @notice Returns true if vault with given config exists
    /// @param _collections vault's config
    /// @return true if vault with given config exists
    function exists(INftVault.CollectionData[] memory _collections) external view returns (bool);

    /// @notice Get config hash
    /// @param _collections vault's config
    /// @return config hash
    function hashVault(INftVault.CollectionData[] memory _collections) external pure returns (bytes32);

    /// @notice Create new vault
    /// @dev If vault already exists, function returned already deployed vault
    /// @param _collections vault's config
    /// @return vault address of (newly) deployed vault
    function createVault(INftVault.CollectionData[] memory _collections) external returns (INftVault vault);
}
