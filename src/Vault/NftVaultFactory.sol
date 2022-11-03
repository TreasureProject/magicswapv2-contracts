// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.17;

import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

import "./INftVaultFactory.sol";
import "./NftVault.sol";

contract NftVaultFactory is INftVaultFactory {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;

    EnumerableSet.AddressSet private vaults;

    mapping(bytes32 => INftVault) public vaultHashMap;
    mapping(INftVault => uint256) public vaultIdMap;

    function getAllVaults() external view returns (address[] memory) {
        return vaults.values();
    }

    function getVaultAt(uint256 _i) external view returns (address) {
        return vaults.at(_i);
    }

    function getVaultLength() external view returns (uint256) {
        return vaults.length();
    }

    function isVault(address _vault) external view returns (uint256) {
        // TODO
    }

    function getVault(INftVault.CollectionData[] memory _collections) public view returns (INftVault vault) {
        vault = vaultHashMap[hashVault(_collections)];
        if (address(vault) == address(0)) revert VaultDoesNotExist();
    }

    function exists(INftVault.CollectionData[] memory _collections) public view returns (bool) {
        return address(vaultHashMap[hashVault(_collections)]) != address(0);
    }

    function hashVault(INftVault.CollectionData[] memory _collections) public pure returns (bytes32) {
        return keccak256(abi.encode(_collections));
    }

    function createVault(INftVault.CollectionData[] memory _collections) external returns (INftVault vault) {
        bytes32 vaultHash = hashVault(_collections);
        vault = INftVault(vaultHashMap[vaultHash]);

        if (address(vault) == address(0)) {
            uint256 vaultId = vaults.length();
            string memory name = string.concat("Magic Vault ", vaultId.toString());
            string memory symbol = string.concat("MagicVault", vaultId.toString());

            vault = INftVault(address(new NftVault(name, symbol)));
            vault.init(_collections);

            vaults.add(address(vault));
            vaultHashMap[vaultHash] = vault;
            vaultIdMap[vault] = vaultId;

            emit VaultCreated(name, symbol, vault, vaultId, _collections, msg.sender);
        }
    }
}
