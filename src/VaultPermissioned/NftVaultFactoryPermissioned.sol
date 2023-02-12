// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

import "./INftVaultFactoryPermissioned.sol";
import "./NftVaultPermissioned.sol";

contract NftVaultFactoryPermissioned is INftVaultFactoryPermissioned {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;

    EnumerableSet.AddressSet private vaults;
    EnumerableSet.AddressSet private permissionedVaults;

    mapping(bytes32 => INftVaultPermissioned) public vaultHashMap;
    mapping(INftVaultPermissioned => uint256) public vaultIdMap;

    /// @inheritdoc INftVaultFactoryPermissioned
    function getAllVaults() external view returns (address[] memory) {
        return vaults.values();
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function getVaultAt(uint256 _i) external view returns (address) {
        return vaults.at(_i);
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function getVaultLength() external view returns (uint256) {
        return vaults.length();
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function isVault(address _vault) external view returns (bool) {
        return vaults.contains(_vault);
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function getAllPermissionedVaults() external view returns (address[] memory) {
        return permissionedVaults.values();
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function getPermissionedVaultAt(uint256 _i) external view returns (address) {
        return permissionedVaults.at(_i);
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function getPermissionedVaultLength() external view returns (uint256) {
        return permissionedVaults.length();
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function isPermissionedVault(address _vault) external view returns (bool) {
        return permissionedVaults.contains(_vault);
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function getVault(INftVaultPermissioned.CollectionData[] memory _collections)
        public
        view
        returns (INftVaultPermissioned vault)
    {
        vault = vaultHashMap[hashVault(_collections)];
        if (address(vault) == address(0)) revert VaultDoesNotExist();
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function exists(INftVaultPermissioned.CollectionData[] memory _collections) public view returns (bool) {
        return address(vaultHashMap[hashVault(_collections)]) != address(0);
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function hashVault(INftVaultPermissioned.CollectionData[] memory _collections) public pure returns (bytes32) {
        return keccak256(abi.encode(_collections));
    }

    /// @inheritdoc INftVaultFactoryPermissioned
    function createVault(INftVaultPermissioned.CollectionData[] memory _collections, address _owner, bool _isSoulbound)
        external
        returns (INftVaultPermissioned vault)
    {
        bool isPermissionless = _owner == address(0) && !_isSoulbound;

        bytes32 vaultHash = hashVault(_collections);
        vault = INftVaultPermissioned(vaultHashMap[vaultHash]);

        // if vault with _collections alredy exists and is permissionless, revert
        if (address(vault) != address(0) && isPermissionless) revert VaultAlreadyDeployed();

        uint256 vaultId;
        string memory name;
        string memory symbol;

        if (isPermissionless) {
            // permissionless
            vaultId = vaults.length();
            name = string.concat("Magic Vault ", vaultId.toString());
            symbol = string.concat("MagicVault", vaultId.toString());
        } else {
            // permissioned
            vaultId = permissionedVaults.length();
            name = string.concat("Magic Permissioned Vault ", vaultId.toString());
            symbol = string.concat("MagicPermissionedVault", vaultId.toString());
        }

        vault = INftVaultPermissioned(address(new NftVaultPermissioned(name, symbol, _owner, _isSoulbound)));
        vault.init(_collections);

        if (isPermissionless) {
            vaults.add(address(vault));
            vaultHashMap[vaultHash] = vault;
            vaultIdMap[vault] = vaultId;
        } else {
            permissionedVaults.add(address(vault));
        }

        emit VaultCreated(name, symbol, vault, vaultId, _collections, msg.sender, _owner);
    }
}
