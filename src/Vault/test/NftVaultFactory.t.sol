// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "lib/ERC721Mintable.sol";
import "lib/ERC1155Mintable.sol";

import "../INftVault.sol";
import "../NftVaultFactory.sol";

contract NftVaultFactoryTest is Test {
    address user1 = address(1001);
    address user2 = address(1002);
    address erc721and1155 = address(888999);

    uint256[] public erc721tokenIds = [1, 6, 15, 22];
    uint256[] public erc721tokenIdsUnsorted = [1, 6, 16, 15, 22];
    uint256[] public erc721tokenIdsDuplicated = [1, 6, 15, 15, 22];
    uint256[] public erc1155tokenIds = [8, 21, 32, 33, 35];

    INftVault.CollectionData public collectionERC721all;
    INftVault.CollectionData public collectionERC1155all;
    INftVault.CollectionData public collectionERC721allowed;
    INftVault.CollectionData public collectionERC1155allowed;
    INftVault.CollectionData public collectionAllWithTokenIds;
    INftVault.CollectionData public collectionERC721allWrongNftType;
    INftVault.CollectionData public collectionERC1155allWrongNftType;
    INftVault.CollectionData public collectionERC721allowedMissingTokens;
    INftVault.CollectionData public collectionERC721allowedUnsortedTokens;
    INftVault.CollectionData public collectionERC721allowedDuplicatedTokens;

    INftVault.CollectionData[] public collections;

    event Deposit(address to, address collection, uint256 tokenId, uint256 amount);

    function setUp() public {
        collectionERC721all = INftVault.CollectionData({
            addr: address(new ERC721Mintable()),
            nftType: INftVault.NftType.ERC721,
            allowAllIds: true,
            tokenIds: new uint256[](0)
        });

        collectionERC1155all = INftVault.CollectionData({
            addr: address(new ERC1155Mintable()),
            nftType: INftVault.NftType.ERC1155,
            allowAllIds: true,
            tokenIds: new uint256[](0)
        });

        collectionERC721allowed = INftVault.CollectionData({
            addr: address(new ERC721Mintable()),
            nftType: INftVault.NftType.ERC721,
            allowAllIds: false,
            tokenIds: erc721tokenIds
        });

        collectionERC1155allowed = INftVault.CollectionData({
            addr: address(new ERC1155Mintable()),
            nftType: INftVault.NftType.ERC1155,
            allowAllIds: false,
            tokenIds: erc1155tokenIds
        });

        collectionAllWithTokenIds = INftVault.CollectionData({
            addr: address(new ERC1155Mintable()),
            nftType: INftVault.NftType.ERC1155,
            allowAllIds: true,
            tokenIds: erc1155tokenIds
        });

        collectionERC721allWrongNftType = INftVault.CollectionData({
            addr: address(new ERC721Mintable()),
            nftType: INftVault.NftType.ERC1155,
            allowAllIds: true,
            tokenIds: new uint256[](0)
        });

        collectionERC1155allWrongNftType = INftVault.CollectionData({
            addr: address(new ERC1155Mintable()),
            nftType: INftVault.NftType.ERC721,
            allowAllIds: true,
            tokenIds: new uint256[](0)
        });

        collectionERC721allowedMissingTokens = INftVault.CollectionData({
            addr: address(new ERC721Mintable()),
            nftType: INftVault.NftType.ERC721,
            allowAllIds: false,
            tokenIds: new uint256[](0)
        });

        collectionERC721allowedUnsortedTokens = INftVault.CollectionData({
            addr: address(new ERC721Mintable()),
            nftType: INftVault.NftType.ERC721,
            allowAllIds: false,
            tokenIds: erc721tokenIdsUnsorted
        });

        collectionERC721allowedDuplicatedTokens = INftVault.CollectionData({
            addr: address(new ERC721Mintable()),
            nftType: INftVault.NftType.ERC721,
            allowAllIds: false,
            tokenIds: erc721tokenIdsDuplicated
        });
    }

    function _getConfig(uint256 configId) public returns (INftVault.CollectionData[] memory) {
        delete collections;

        // deploy fresh NFTs at every config request
        collectionERC721all.addr = address(new ERC721Mintable());
        collectionERC1155all.addr = address(new ERC1155Mintable());
        collectionERC721allowed.addr = address(new ERC721Mintable());
        collectionERC1155allowed.addr = address(new ERC1155Mintable());

        if (configId == 0) {
            collections.push(collectionERC721all);
        } else if(configId == 1) {
            collections.push(collectionERC1155all);
        } else if(configId == 2) {
            collections.push(collectionERC721allowed);
        } else if(configId == 3) {
            collections.push(collectionERC1155allowed);
        } else if(configId == 4) {
            collections.push(collectionERC721all);
            collections.push(collectionERC1155all);
        } else if(configId == 5) {
            collections.push(collectionERC721allowed);
            collections.push(collectionERC1155allowed);
        } else if(configId == 6) {
            collections.push(collectionERC721all);
            collections.push(collectionERC1155allowed);
        } else if(configId == 7) {
            collections.push(collectionERC721allowed);
            collections.push(collectionERC1155all);
        } else {
            revert("WrongConfig");
        }

        return collections;
    }

    function testAllGetters() public {
        NftVaultFactory vaultFactory = new NftVaultFactory();

        address[] memory vaults = new address[](8);

        for (uint256 configId = 0; configId < 8; configId++) {
            INftVault.CollectionData[] memory _collections = _getConfig(configId);
            INftVault vault = vaultFactory.createVault(_collections);

            vaults[configId] = address(vault);

            address[] memory getAllVaults = new address[](configId + 1);
            for (uint256 i = 0; i < getAllVaults.length; i++) {
                if (vaults[i] != address(0)) {
                    getAllVaults[i] = vaults[i];
                }
            }

            assertEq(vaultFactory.getAllVaults(), getAllVaults);
            assertEq(vaultFactory.getVaultAt(configId), vaults[configId]);
            assertEq(vaultFactory.getVaultLength(), configId + 1);
            assertEq(vaultFactory.isVault(vaults[configId]), true);
            assertEq(vaultFactory.isVault(address(uint160(vaults[configId]) + 1)), false);
            assertEq(address(vaultFactory.getVault(_collections)), vaults[configId]);
            assertEq(vaultFactory.exists(_collections), true);
            assertEq(address(vaultFactory.vaultHashMap(vaultFactory.hashVault(_collections))), vaults[configId]);
            assertEq(vaultFactory.getVaultAt(vaultFactory.vaultIdMap(INftVault(vaults[configId]))), vaults[configId]);
        }
    }
}
