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
        address creator,
        address owner
    );

    /// @dev Vault does not exist
    error VaultDoesNotExist();

    /// @dev Vault with identical configuration is already deployed
    error VaultAlreadyDeployed();

    /// @notice Get vault by its config hash
    /// @param hash vault's config hash
    /// @return vault address
    function vaultHashMap(bytes32 hash) external view returns (INftVault vault);

    /// @return all deployed vaults
    function getAllVaults() external view returns (address[] memory);

    /// @notice Get vault by its EnumerableSet vaultId
    /// @param i vaultId
    /// @return vault address
    function getVaultAt(uint256 i) external view returns (address);

    /// @return length of vault's EnumerableSet
    function getVaultLength() external view returns (uint256);

    /// @notice Returns true if vault has been deployed by factory
    /// @param vault address
    function isVault(address vault) external view returns (bool);

    /// @return all deployed permissioned vaults
    function getAllPermissionedVaults() external view returns (address[] memory);

    /// @notice Get permissioned vault by its EnumerableSet vaultId
    /// @param i vaultId
    /// @return vault address
    function getPermissionedVaultAt(uint256 i) external view returns (address);

    /// @return length of permissioned vault's EnumerableSet
    function getPermissionedVaultLength() external view returns (uint256);

    /// @notice Returns true if permissioned vault has been deployed by factory
    /// @param vault address
    function isPermissionedVault(address vault) external view returns (bool);

    /// @notice Get vault by it's config
    /// @param collections vault's config
    /// @return vault address
    function getVault(INftVault.CollectionData[] memory collections) external view returns (INftVault vault);

    /// @notice Returns true if vault with given config exists
    /// @param collections vault's config
    /// @return true if vault with given config exists
    function exists(INftVault.CollectionData[] memory collections) external view returns (bool);

    /// @notice Get config hash
    /// @param collections vault's config
    /// @return config hash
    function hashVault(INftVault.CollectionData[] memory collections) external pure returns (bytes32);

    /// @notice Create new vault
    /// @dev If vault already exists, function returned already deployed vault
    /// @param collections vault's config
    /// @param owner address of owner if vault is permissioned, otherwise address(0) and vault is permissionless
    /// @return vault address of (newly) deployed vault
    function createVault(INftVault.CollectionData[] memory collections, address owner) external returns (INftVault vault);
}
