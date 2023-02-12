// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

import "./INftVaultFactory.sol";
import "./NftVault.sol";

contract NftVaultFactory is INftVaultFactory {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;

    EnumerableSet.AddressSet private vaults;

    mapping(bytes32 => INftVault) public vaultHashMap;
    mapping(INftVault => uint256) public vaultIdMap;

    /// @inheritdoc INftVaultFactory
    function getAllVaults() external view returns (address[] memory) {
        return vaults.values();
    }

    /// @inheritdoc INftVaultFactory
    function getVaultAt(uint256 _index) external view returns (address) {
        return vaults.at(_index);
    }

    /// @inheritdoc INftVaultFactory
    function getVaultLength() external view returns (uint256) {
        return vaults.length();
    }

    /// @inheritdoc INftVaultFactory
    function isVault(address _vault) external view returns (bool) {
        return vaults.contains(_vault);
    }

    /// @inheritdoc INftVaultFactory
    function getVault(INftVault.CollectionData[] memory _collections) public view returns (INftVault vault) {
        vault = vaultHashMap[hashVault(_collections)];
        if (address(vault) == address(0)) revert VaultDoesNotExist();
    }

    /// @inheritdoc INftVaultFactory
    function exists(INftVault.CollectionData[] memory _collections) public view returns (bool) {
        return address(vaultHashMap[hashVault(_collections)]) != address(0);
    }

    /// @inheritdoc INftVaultFactory
    function hashVault(INftVault.CollectionData[] memory _collections) public pure returns (bytes32) {
        return keccak256(abi.encode(_collections));
    }

    /// @inheritdoc INftVaultFactory
    function createVault(INftVault.CollectionData[] memory _collections) external returns (INftVault vault) {
        bytes32 vaultHash = hashVault(_collections);
        vault = INftVault(vaultHashMap[vaultHash]);

        // if vault with _collections alredy exists, revert
        if (address(vault) != address(0)) revert VaultAlreadyDeployed();

        uint256 vaultId;
        string memory name;
        string memory symbol;

        vaultId = vaults.length();
        name = string.concat("Magic Vault ", vaultId.toString());
        symbol = string.concat("MagicVault", vaultId.toString());

        vault = INftVault(address(new NftVault(name, symbol)));
        vault.init(_collections);

        vaults.add(address(vault));
        vaultHashMap[vaultHash] = vault;
        vaultIdMap[vault] = vaultId;

        emit VaultCreated(name, symbol, vault, vaultId, _collections, msg.sender);
    }
}
