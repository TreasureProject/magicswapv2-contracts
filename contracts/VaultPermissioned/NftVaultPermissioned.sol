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

import "./INftVaultPermissioned.sol";
import "./INftVaultFactoryPermissioned.sol";

contract NftVaultPermissioned is INftVaultPermissioned, ERC20, ERC721Holder, ERC1155Holder, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice value of 1 token, including decimals
    uint256 public immutable ONE;

    /// @notice minimum liquidity that is frozen in UniV2 pool
    uint256 public constant UNIV2_MINIMUM_LIQUIDITY = 1e3;

    /// @notice if Vault is soulbound, its ERC20 token can only be transfered to
    ///         EOA, vault itself and `allowedContracts`
    bool public immutable isSoulbound;

    /// @notice unique ID of the vault generated using its configuration
    bytes32 public VAULT_HASH;

    /// @notice maps collection address to nft type
    EnumerableMap.AddressToUintMap private allowedCollections;

    /// @notice maps collection address to allowed tokens
    mapping(address => AllowedTokenIds) private allowedTokenIds;

    /// @notice maps collection address to tokenId to amount wrapped
    mapping(address => mapping(uint256 => uint256)) public balances;

    /// @notice deposit/withdraw allow list. Maps wallet address to bool, if true, wallet is allowed to deposit/withdraw
    mapping(address => bool) public allowedWallets;

    /// @notice Vault ERC20 receive allow list. Maps contract address to bool, if true, contract is allowed to receive
    ///         Vault ERC20 token.
    mapping(address => bool) public allowedContracts;

    modifier onlyAllowed() {
        if (isPermissioned() && !allowedWallets[msg.sender]) {
            revert NotAllowed();
        }

        _;
    }

    /// @dev if _owner == address(0), NftVault is deployed as permissionless
    /// @param _name name of ERC20 Vault token
    /// @param _symbol symbol of ERC20 Vault token
    /// @param _owner should be address(0) for permissionless vaults. Otherwise, address of the owner.
    /// @param _isSoulbound if true, Vault is soulbound, false otherwise
    constructor(string memory _name, string memory _symbol, address _owner, bool _isSoulbound) ERC20(_name, _symbol) {
        ONE = 10 ** decimals();

        isSoulbound = _isSoulbound;
        _transferOwnership(_owner);

        if (_isSoulbound && _owner == address(0)) revert OwnerRequiredForSoulbound();
    }

    /// @inheritdoc INftVaultPermissioned
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

    /// @inheritdoc INftVaultPermissioned
    function isPermissioned() public view returns (bool) {
        return owner() != address(0);
    }

    /// @inheritdoc INftVaultPermissioned
    function hashVault(INftVaultPermissioned.CollectionData[] memory _collections) public pure returns (bytes32) {
        return keccak256(abi.encode(_collections));
    }

    /// @inheritdoc INftVaultPermissioned
    function getAllowedCollections() external view returns (address[] memory collections) {
        collections = new address[](allowedCollections.length());

        for (uint256 i = 0; i < collections.length; i++) {
            (address addr,) = allowedCollections.at(i);
            collections[i] = addr;
        }
    }

    /// @inheritdoc INftVaultPermissioned
    function getAllowedCollectionsLength() external view returns (uint256) {
        return allowedCollections.length();
    }

    /// @inheritdoc INftVaultPermissioned
    function getAllowedCollectionData(address _collectionAddr) external view returns (CollectionData memory) {
        return CollectionData({
            addr: _collectionAddr,
            nftType: NftType(allowedCollections.get(_collectionAddr)),
            allowAllIds: allowedTokenIds[_collectionAddr].allowAllIds,
            tokenIds: allowedTokenIds[_collectionAddr].tokenIdList
        });
    }

    /// @inheritdoc INftVaultPermissioned
    function validateNftType(address _collectionAddr, NftType _nftType) public view returns (uint256 nftType) {
        bool supportsERC721 = ERC165Checker.supportsInterface(_collectionAddr, type(IERC721).interfaceId);
        bool supportsERC1155 = ERC165Checker.supportsInterface(_collectionAddr, type(IERC1155).interfaceId);

        /// @dev if `_collectionAddr` supports both or neither token standard, trust user input
        ///      if `_collectionAddr` supports one of the token standards, NftType must match it
        if (supportsERC721 && !supportsERC1155 && _nftType != NftType.ERC721) revert ExpectedERC721();
        if (supportsERC1155 && !supportsERC721 && _nftType != NftType.ERC1155) revert ExpectedERC1155();

        nftType = uint256(_nftType);
    }

    /// @inheritdoc INftVaultPermissioned
    function isTokenAllowed(address _collection, uint256 _tokenId) public view returns (bool) {
        (bool isCollectionAllowed,) = allowedCollections.tryGet(_collection);

        return isCollectionAllowed
            && (allowedTokenIds[_collection].allowAllIds || allowedTokenIds[_collection].tokenIds[_tokenId]);
    }

    /// @inheritdoc INftVaultPermissioned
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

    /// @inheritdoc INftVaultPermissioned
    function deposit(address _to, address _collection, uint256 _tokenId, uint256 _amount)
        public
        onlyAllowed
        returns (uint256 amountMinted)
    {
        if (!isTokenAllowed(_collection, _tokenId)) revert DisallowedToken();

        uint256 sentTokenBalance = getSentTokenBalance(_collection, _tokenId);
        if (_amount == 0 || sentTokenBalance < _amount) revert WrongAmount();

        balances[_collection][_tokenId] += _amount;
        emit Deposit(_to, _collection, _tokenId, _amount);

        amountMinted = ONE * _amount;
        _mint(_to, amountMinted);
    }

    /// @inheritdoc INftVaultPermissioned
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

    /// @inheritdoc INftVaultPermissioned
    function withdraw(address _to, address _collection, uint256 _tokenId, uint256 _amount)
        public
        onlyAllowed
        returns (uint256 amountBurned)
    {
        if (_amount == 0 || balances[_collection][_tokenId] < _amount) revert WrongAmount();

        balances[_collection][_tokenId] -= _amount;
        amountBurned = ONE * _amount;

        // when withdrawing the last NFT from the vault, allow being UNIV2_MINIMUM_LIQUIDITY shy
        if (totalSupply() == amountBurned && balanceOf(address(this)) == amountBurned - UNIV2_MINIMUM_LIQUIDITY) {
            amountBurned -= UNIV2_MINIMUM_LIQUIDITY;
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

    /// @inheritdoc INftVaultPermissioned
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

    /// @inheritdoc INftVaultPermissioned
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

    function _beforeTokenTransfer(address, /*from*/ address to, uint256 /*amount*/ ) internal view override {
        /// @dev Soulbound Vault ERC20 token can be transfered to any EOA, this Vault or `allowedContracts`
        if (isSoulbound && to != address(this) && Address.isContract(to) && !allowedContracts[to]) {
            revert SoulboundTransferDisallowed();
        }
    }

    /// @inheritdoc INftVaultPermissioned
    function allowDepositWithdraw(address _wallet) external onlyOwner {
        allowedWallets[_wallet] = true;

        emit AllowedDepositWithdraw(_wallet);
    }

    /// @inheritdoc INftVaultPermissioned
    function disallowDepositWithdraw(address _wallet) external onlyOwner {
        allowedWallets[_wallet] = false;

        emit DisallowedDepositWithdraw(_wallet);
    }

    /// @inheritdoc INftVaultPermissioned
    function allowVaultTokenTransfersTo(address _contractAddress) external onlyOwner {
        allowedContracts[_contractAddress] = true;

        emit AllowedContract(_contractAddress);
    }

    /// @inheritdoc INftVaultPermissioned
    function disallowVaultTokenTransfersTo(address _contractAddress) external onlyOwner {
        allowedContracts[_contractAddress] = false;

        emit DisallowedContract(_contractAddress);
    }
}
