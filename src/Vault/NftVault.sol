// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.17;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";
import "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";

import "./INftVault.sol";
import "./INftVaultFactory.sol";

contract NftVault is INftVault, ERC20, ERC721Holder, ERC1155Holder {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice value of 1 token, including decimals
    uint256 public immutable ONE;

    /// @notice unique it of the vault geenrated using its configuration
    bytes32 public VAULT_HASH;

    /// @notice maps collection address to nft type
    EnumerableMap.AddressToUintMap private allowedCollections;

    /// @notice maps collection address to allowed tokens
    mapping(address => AllowedTokenIds) private allowedTokenIds;

    /// @notice maps collection address to tokenId to amount wrapped
    mapping(address => mapping(uint256 => uint256)) public balances;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        ONE = 10**decimals();
    }

    /// @notice Initialize Vault with collection config
    /// @dev Called by factory during deployment
    function init(CollectionData[] memory _collections) external {
        if (_collections.length == 0) revert InvalidCollections();
        if (allowedCollections.length() > 0) revert Initialized();

        VAULT_HASH = hashVault(_collections);

        for (uint256 i = 0; i < _collections.length; i++) {
            CollectionData memory collection = _collections[i];

            /// @dev if all Ids are allowed tokenIds must be empty, otherwise VAULT_HASH will not be correct
            if (collection.allowAllIds && collection.tokenIds.length > 0) revert TokenIdsMustBeEmpty();

            uint256 nftType = validateNftType(collection.addr, collection.nftType);

            allowedCollections.set(collection.addr, nftType);
            allowedTokenIds[collection.addr].allowAllIds = collection.allowAllIds;

            if (collection.allowAllIds) continue;
            if (collection.tokenIds.length == 0) revert MissingTokenIds();

            uint256 lastTokenId = 0;

            for (uint256 j = 0; j < collection.tokenIds.length; j++) {
                uint256 tokenId = collection.tokenIds[j];

                /// @dev Make sure `uint256[] tokenIds` array is sorted,
                ///      otherwise VAULT_HASH will not be correct
                if (tokenId < lastTokenId) {
                    revert TokenIdsMustBeSorted();
                } else {
                    lastTokenId = tokenId;
                }

                /// @dev Check for duplicates
                if (allowedTokenIds[collection.addr].tokenIds[tokenId]) revert TokenIdAlreadySet();

                allowedTokenIds[collection.addr].tokenIds[tokenId] = true;
                allowedTokenIds[collection.addr].tokenIdList.push(tokenId);
            }

            emit CollectionAllowed(collection);
        }
    }

    function hashVault(INftVault.CollectionData[] memory _collections) public pure returns (bytes32) {
        return keccak256(abi.encode(_collections));
    }

    function getAllowedCollections() external view returns (address[] memory collections) {
        collections = new address[](allowedCollections.length());

        for (uint256 i = 0; i < collections.length; i++) {
             (address addr,) = allowedCollections.at(i);
             collections[i] = addr;
        }
    }

    function getAllowedCollectionsLength() external view returns (uint256) {
        return allowedCollections.length();
    }

    function getAllowedCollectionData(address _collectionAddr) external view returns (CollectionData memory) {
        return CollectionData({
            addr: _collectionAddr,
            nftType: NftType(allowedCollections.get(_collectionAddr)),
            allowAllIds: allowedTokenIds[_collectionAddr].allowAllIds,
            tokenIds: allowedTokenIds[_collectionAddr].tokenIdList
        });
    }

    function validateNftType(address _collectionAddr, NftType _nftType) public view returns (uint256 nftType) {
        bool supportsERC721 = ERC165Checker.supportsInterface(_collectionAddr, type(IERC721).interfaceId);
        bool supportsERC1155 = ERC165Checker.supportsInterface(_collectionAddr, type(IERC1155).interfaceId);

        /// @dev if `_collectionAddr` supports both or neither token standard, trust user input
        ///      if `_collectionAddr` supports one of the token standards, NftType must match it
        if (supportsERC721 && !supportsERC1155 && _nftType != NftType.ERC721) revert ExpectedERC721();
        if (supportsERC1155 && !supportsERC721 && _nftType != NftType.ERC1155) revert ExpectedERC1155();

        nftType = uint256(_nftType);
    }

    function isTokenAllowed(address _collection, uint256 _tokenId) public view returns (bool) {
        (bool isCollectionAllowed,) = allowedCollections.tryGet(_collection);

        return
            isCollectionAllowed &&
            (
                allowedTokenIds[_collection].allowAllIds ||
                allowedTokenIds[_collection].tokenIds[_tokenId]
            );
    }

    function getSentTokenBalance(address _collection, uint256 _tokenId) public view returns (uint256) {
        uint256 currentBalance = balances[_collection][_tokenId];
        NftType nftType = NftType(allowedCollections.get(_collection));

        if (nftType == NftType.ERC721) {
            if (currentBalance == 0 && IERC721(_collection).ownerOf(_tokenId) == address(this)) {
                return 1;
            } else {
                return 0;
            }
        } else if (nftType == NftType.ERC1155) {
            return IERC1155(_collection).balanceOf(address(this), _tokenId) - currentBalance;
        } else {
            revert UnsupportedNft();
        }
    }

    function deposit(
        address _to,
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) public returns (uint256 amountMinted) {
        if (!isTokenAllowed(_collection, _tokenId)) revert DisallowedToken();

        uint256 sentTokenBalance = getSentTokenBalance(_collection, _tokenId);
        if (_amount == 0 || sentTokenBalance < _amount) revert WrongAmount();

        balances[_collection][_tokenId] += _amount;
        emit Deposit(_to, _collection, _tokenId, _amount);

        amountMinted = ONE * _amount;
        _mint(_to, amountMinted);
    }

    function depositBatch(
        address _to,
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount
    ) external returns (uint256 amountMinted) {
        for (uint256 i = 0; i < _collection.length; i++) {
            amountMinted += deposit(_to, _collection[i], _tokenId[i], _amount[i]);
        }
    }

    function withdraw(
        address _to,
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) public returns (uint256 amountBurned) {
        if (_amount == 0 || balances[_collection][_tokenId] < _amount) revert WrongAmount();

        balances[_collection][_tokenId] -= _amount;
        amountBurned = ONE * _amount;
        _burn(address(this), amountBurned);

        NftType nftType = NftType(allowedCollections.get(_collection));
        if (nftType == NftType.ERC721) {
            if (_amount != 1) revert WrongERC721Amount();

            IERC721(_collection).safeTransferFrom(address(this), _to, _tokenId);
        } else if (nftType == NftType.ERC1155) {
            IERC1155(_collection).safeTransferFrom(address(this), _to, _tokenId, _amount, bytes(""));
        } else {
            revert UnsupportedNft();
        }

        emit Withdraw(_to, _collection, _tokenId, _amount);
    }

    function withdrawBatch(
        address _to,
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount
    ) external returns (uint256 amountBurned) {
        for (uint256 i = 0; i < _collection.length; i++) {
            amountBurned += withdraw(_to, _collection[i], _tokenId[i], _amount[i]);
        }
    }

    /// @notice Allow anyone to withdraw tokens sent to this vault by accident
    function skim(
        address _to,
        NftType nftType,
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        /// @dev Cannot skim supported token
        if (isTokenAllowed(_collection, _tokenId)) revert MustBeDisallowedToken();

        if (nftType == NftType.ERC721) {
            IERC721(_collection).safeTransferFrom(address(this), _to, _tokenId);
        } else if (nftType == NftType.ERC1155) {
            IERC1155(_collection).safeTransferFrom(address(this), _to, _tokenId, _amount, bytes(""));
        } else {
            revert UnsupportedNft();
        }
    }

}