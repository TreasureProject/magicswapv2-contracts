// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

import "./INftVaultFactory.sol";
import "./NftVault.sol";

contract NftVaultFactory is INftVaultFactory, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;

    EnumerableSet.AddressSet private vaults;
    EnumerableSet.AddressSet private permissionedVaults;

    //Create the admin for this vault creation role.
    bytes32 constant MAGICSWAP_VAULT_CREATOR_ADMIN_ROLE = keccak256("MAGICSWAP_VAULT_CREATOR_ADMIN");

    //Create the basic role for creating vaults.
    bytes32 constant MAGICSWAP_VAULT_CREATOR_ROLE = keccak256("MAGICSWAP_VAULT_CREATOR");

    bool vaultsCreatableByAll;

    mapping(bytes32 => INftVault) public vaultHashMap;
    mapping(INftVault => uint256) public vaultIdMap;

    constructor(){
        //Set the magicswap creator admin roles admin to itself, so if you are an admin you can add or remove accounts from being an admin
        _setRoleAdmin(MAGICSWAP_VAULT_CREATOR_ADMIN_ROLE, MAGICSWAP_VAULT_CREATOR_ADMIN_ROLE);

        //Set the admin of the vault creator role to the admin role
        //This means anyone with the admin role can add or remove users from the creation roles
        _setRoleAdmin(MAGICSWAP_VAULT_CREATOR_ROLE, MAGICSWAP_VAULT_CREATOR_ADMIN_ROLE);

        //Grant the deployer the admin role
        _grantRole(MAGICSWAP_VAULT_CREATOR_ADMIN_ROLE, msg.sender);

        //Grant the deployer the creator role
        _grantRole(MAGICSWAP_VAULT_CREATOR_ROLE, msg.sender);
    }

    function grantVaultCreator(address _user) external onlyRole(MAGICSWAP_VAULT_CREATOR_ADMIN_ROLE) {
        //Grant the user the creator role
        _grantRole(MAGICSWAP_VAULT_CREATOR_ROLE, _user);
    }

    function revokeVaultCreator(address _user) external onlyRole(MAGICSWAP_VAULT_CREATOR_ADMIN_ROLE) {
        //Revoke the user the creator role
        _revokeRole(MAGICSWAP_VAULT_CREATOR_ROLE, _user);
    }

    /// @inheritdoc INftVaultFactory
    function getAllVaults() external view returns (address[] memory) {
        return vaults.values();
    }

    /// @inheritdoc INftVaultFactory
    function getVaultAt(uint256 _i) external view returns (address) {
        return vaults.at(_i);
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
    function getAllPermissionedVaults() external view returns (address[] memory) {
        return permissionedVaults.values();
    }

    /// @inheritdoc INftVaultFactory
    function getPermissionedVaultAt(uint256 _i) external view returns (address) {
        return permissionedVaults.at(_i);
    }

    /// @inheritdoc INftVaultFactory
    function getPermissionedVaultLength() external view returns (uint256) {
        return permissionedVaults.length();
    }

    /// @inheritdoc INftVaultFactory
    function isPermissionedVault(address _vault) external view returns (bool) {
        return permissionedVaults.contains(_vault);
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
    function createVault(
        INftVault.CollectionData[] memory _collections,
        address _owner,
        bool _isSoulbound
    ) external returns (INftVault vault) {
        if(!vaultsCreatableByAll) require(hasRole(MAGICSWAP_VAULT_CREATOR_ROLE, msg.sender), "Sender is not a vault creator.");

        bool isPermissionless = _owner == address(0) && !_isSoulbound;

        bytes32 vaultHash = hashVault(_collections);
        vault = INftVault(vaultHashMap[vaultHash]);

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

        vault = INftVault(address(new NftVault(name, symbol, _owner, _isSoulbound)));
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

    function setVaultsCreatableByAll(bool _vaultsCreatableByAll) external onlyRole(MAGICSWAP_VAULT_CREATOR_ADMIN_ROLE) {
        vaultsCreatableByAll = _vaultsCreatableByAll;
    }
}
