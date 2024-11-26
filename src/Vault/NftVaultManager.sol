// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./INftVault.sol";

contract NftVaultManager {
    function withdrawBatch(
        address _vault,
        address[] memory _collections,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) external returns (uint256) {
        INftVault vault = INftVault(_vault);

        uint256 totalAmount;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }

        IERC20(_vault).transferFrom(msg.sender, _vault, totalAmount * vault.ONE());
        return vault.withdrawBatch(msg.sender, _collections, _tokenIds, _amounts);
    }

    function depositBatch(
        address _vault,
        address[] memory _collections,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) external returns (uint256) {
        INftVault vault = INftVault(_vault);
        address collectionAddress;

        for (uint256 i = 0; i < _collections.length; i++) {
            collectionAddress = _collections[i];
            INftVault.CollectionData memory collectionData = vault.getAllowedCollectionData(
                collectionAddress
            );
            if (collectionData.nftType == INftVault.NftType.ERC1155) {
                IERC1155(collectionAddress).safeTransferFrom(
                    msg.sender,
                    _vault,
                    _tokenIds[i],
                    _amounts[i],
                    ""
                );
            } else if (collectionData.nftType == INftVault.NftType.ERC721) {
                IERC721(collectionAddress).safeTransferFrom(msg.sender, _vault, _tokenIds[i]);
            } else {
                revert("NftVaultManager: Invalid NFT type");
            }
        }
        return vault.depositBatch(msg.sender, _collections, _tokenIds, _amounts);
    }
}
