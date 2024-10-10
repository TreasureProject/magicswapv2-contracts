// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";
import "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import "lib/openzeppelin-contracts/contracts/utils/Address.sol";

import "./INftVault.sol";
import "./INftVaultFactory.sol";

contract NftVault is INftVault, ERC20, ERC721Holder, ERC1155Holder {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice value of 1 token, including decimals
    uint256 public immutable ONE;

    /// @notice amount of token required for last NFT to be redeemed
    uint256 public immutable LAST_NFT_AMOUNT;

    /// @notice unique ID of the vault generated using its configuration
    bytes32 public VAULT_HASH;

    /// @notice maps collection address to nft type
    EnumerableMap.AddressToUintMap private allowedCollections;

    /// @notice maps collection address to allowed tokens
    mapping(address => AllowedTokenIds) private allowedTokenIds;

    /// @notice maps collection address to tokenId to amount wrapped
    mapping(address => mapping(uint256 => uint256)) public balances;

    /// @param _name name of ERC20 Vault token
    /// @param _symbol symbol of ERC20 Vault token
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        ONE = 10 ** decimals();
        /// @dev last NFT can be redeemed for 99.9%
        LAST_NFT_AMOUNT = ONE * 999 / 1000;
    }

    /// @inheritdoc INftVault
    function init(CollectionData[] memory _collections) external {
        if (_collections.length == 0) revert InvalidCollections();
        if (allowedCollections.length() > 0) revert Initialized();

        VAULT_HASH = hashVault(_collections);

        for (uint256 i = 0; i < _collections.length; i++) {
            CollectionData memory collection = _collections[i];

            /// @dev if all Ids are allowed tokenIds must be empty, otherwise VAULT_HASH will not be correct
            if (collection.allowAllIds && collection.tokenIds.length > 0) revert TokenIdsMustBeEmpty();

            uint256 nftType = validateNftType(collection.addr, collection.nftType);

            if (!allowedCollections.set(collection.addr, nftType)) revert DuplicateCollection();
            allowedTokenIds[collection.addr].allowAllIds = collection.allowAllIds;

            emit CollectionAllowed(collection);

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
        }
    }

    /// @inheritdoc INftVault
    function hashVault(INftVault.CollectionData[] memory _collections) public pure returns (bytes32) {
        return keccak256(abi.encode(_collections));
    }

    /// @inheritdoc INftVault
    function getAllowedCollections() external view returns (address[] memory collections) {
        collections = new address[](allowedCollections.length());

        for (uint256 i = 0; i < collections.length; i++) {
            (address addr,) = allowedCollections.at(i);
            collections[i] = addr;
        }
    }

    /// @inheritdoc INftVault
    function getAllowedCollectionsLength() external view returns (uint256) {
        return allowedCollections.length();
    }

    /// @inheritdoc INftVault
    function getAllowedCollectionData(address _collectionAddr) external view returns (CollectionData memory) {
        return CollectionData({
            addr: _collectionAddr,
            nftType: NftType(allowedCollections.get(_collectionAddr)),
            allowAllIds: allowedTokenIds[_collectionAddr].allowAllIds,
            tokenIds: allowedTokenIds[_collectionAddr].tokenIdList
        });
    }

    /// @inheritdoc INftVault
    function validateNftType(address _collectionAddr, NftType _nftType) public view returns (uint256 nftType) {
        bool supportsERC721 = ERC165Checker.supportsInterface(_collectionAddr, type(IERC721).interfaceId);
        bool supportsERC1155 = ERC165Checker.supportsInterface(_collectionAddr, type(IERC1155).interfaceId);

        /// @dev if `_collectionAddr` supports both or neither token standard, trust user input
        ///      if `_collectionAddr` supports one of the token standards, NftType must match it
        if (supportsERC721 && !supportsERC1155 && _nftType != NftType.ERC721) revert ExpectedERC721();
        if (supportsERC1155 && !supportsERC721 && _nftType != NftType.ERC1155) revert ExpectedERC1155();

        nftType = uint256(_nftType);
    }

    /// @inheritdoc INftVault
    function isTokenAllowed(address _collection, uint256 _tokenId) public view returns (bool) {
        (bool isCollectionAllowed,) = allowedCollections.tryGet(_collection);

        return isCollectionAllowed
            && (allowedTokenIds[_collection].allowAllIds || allowedTokenIds[_collection].tokenIds[_tokenId]);
    }

    /// @inheritdoc INftVault
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

    /// @inheritdoc INftVault
    function deposit(address _to, address _collection, uint256 _tokenId, uint256 _amount)
        public
        returns (uint256 amountMinted)
    {
        if (!isTokenAllowed(_collection, _tokenId)) revert DisallowedToken();

        uint256 sentTokenBalance = getSentTokenBalance(_collection, _tokenId);
        if (_amount == 0 || sentTokenBalance < _amount) revert WrongAmount();

        balances[_collection][_tokenId] += _amount;
        emit Deposit(_to, _collection, _tokenId, _amount);

        amountMinted = ONE * _amount;
        uint256 totalSupply_ = totalSupply();

        /// @dev If vault ERC20 supply is "0 < totalSupply <= 0.01" it means that vault has been emptied and there
        ///      is leftover ERC20 token (most likely) locked in the univ2 pair. To prevent minting small amounts
        ///      of unbacked ERC20 tokens in a loop, which can lead to unexpected behaviour, vault mints
        ///      `ONE - totalSupply` amount of ERC20 token for the first NFT that is deposited after the vault was
        ///      emptied. This allows for the vault and univ2 pair to be reused safely.
        if (totalSupply_ > 0 && totalSupply_ <= ONE - LAST_NFT_AMOUNT) {
            amountMinted -= totalSupply_;
        }

        _mint(_to, amountMinted);
    }

    /// @inheritdoc INftVault
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

    /// @inheritdoc INftVault
    function withdraw(address _to, address _collection, uint256 _tokenId, uint256 _amount)
        public
        returns (uint256 amountBurned)
    {
        if (_amount == 0 || balances[_collection][_tokenId] < _amount) revert WrongAmount();

        balances[_collection][_tokenId] -= _amount;
        amountBurned = ONE * _amount;

        // when withdrawing the last NFT from the vault, allow redeemeing for LAST_NFT_AMOUNT instead of ONE
        if (totalSupply() == amountBurned && balanceOf(address(this)) >= amountBurned - ONE + LAST_NFT_AMOUNT) {
            amountBurned = balanceOf(address(this));
        }

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

    /// @inheritdoc INftVault
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

    /// @inheritdoc INftVault
    function skim(address _to, NftType nftType, address _collection, uint256 _tokenId, uint256 _amount) external {
        // Cannot skim supported token
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
