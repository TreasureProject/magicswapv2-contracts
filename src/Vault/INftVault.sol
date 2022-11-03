// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.17;

interface INftVault {
    enum NftType { ERC721, ERC1155 }

    struct CollectionData {
        address addr;
        NftType nftType;
        bool allowAllIds;
        uint256[] tokenIds;
    }

    struct AllowedTokenIds {
        mapping(uint256 => bool) tokenIds;
        uint256[] tokenIdList;
        bool allowAllIds;
    }

    event CollectionAllowed(CollectionData collection);
    event Deposit(address to, address collection, uint256 tokenId, uint256 amount);
    event Withdraw(address _to, address _collection, uint256 _tokenId, uint256 _amount);

    error Initialized();
    error InvalidCollections();
    error TokenIdAlreadySet();
    error TokenIdsMustBeSorted();
    error ExpectedERC721();
    error ExpectedERC1155();
    error MissingTokenIds();
    error TokenIdsMustBeEmpty();
    error DisallowedToken();
    error WrongAmount();
    error WrongERC721Amount();
    error UnsupportedNft();
    error MustBeDisallowedToken();

    /// @notice value of 1 token, including decimals
    function ONE() external view returns (uint256);
    /// @notice unique it of the vault geenrated using its configuration
    function VAULT_HASH() external view returns (bytes32);

    function init(CollectionData[] memory _collections) external;
    function balances(address _collectionAddr, uint256 _tokenId) external view returns (uint256 amount);

    function getAllowedCollections() external view returns (address[] memory collections);
    function getAllowedCollectionsLength() external view returns (uint256);
    function getAllowedCollectionData(address _collectionAddr) external view returns (CollectionData memory);

    function validateNftType(address _collectionAddr, NftType _nftType) external view returns (uint256 nftType);
    function isTokenAllowed(address _collection, uint256 _tokenId) external view returns (bool);
    function getSentTokenBalance(address _collection, uint256 _tokenId) external view returns (uint256);

    function deposit(
        address _to,
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) external returns (uint256 amountMinted);

    function depositBatch(
        address _to,
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount
    ) external returns (uint256 amountMinted);

    function withdraw(
        address _to,
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) external returns (uint256 amountBurned);

    function withdrawBatch(
        address _to,
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount
    ) external returns (uint256 amountBurned);

    /// @notice Allow anyone to withdraw tokens sent to this vault by accident
    function skim(
        address _to,
        NftType nftType,
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) external;

}
