// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "./INftVault.sol";

interface INftVaultFactory {
    event VaultCreated(
        string name,
        string symbol,
        INftVault vault,
        uint256 vaultId,
        INftVault.CollectionData[] collections,
        address creator
    );

    error VaultDoesNotExist();

    function vaultHashMap(bytes32 _hash) external view returns (INftVault vault);

    function getAllVaults() external view returns (address[] memory);
    function getVaultAt(uint256 _i) external view returns (address);
    function getVaultLength() external view returns (uint256);
    function isVault(address _vault) external view returns (bool);
    function getVault(INftVault.CollectionData[] memory _collections) external view returns (INftVault vault);
    function exists(INftVault.CollectionData[] memory _collections) external view returns (bool);
    function hashVault(INftVault.CollectionData[] memory _collections) external pure returns (bytes32);

    function createVault(INftVault.CollectionData[] memory _collections) external returns (INftVault vault);
}
