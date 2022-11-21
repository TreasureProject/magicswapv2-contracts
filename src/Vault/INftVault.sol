// SPDX-License-Identifier: MIT
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

    /// @notice unique id of the vault generated using its configuration
    function VAULT_HASH() external view returns (bytes32);

    /// @notice Initialize Vault with collection config
    /// @dev Called by factory during deployment
    /// @param _collections struct array of allowed collections and token IDs
    function init(CollectionData[] memory _collections) external;

    /// @notice Returns hash of vault configuration
    /// @param _collections struct array of allowed collections and token IDs
    /// @return configuration hash
    function hashVault(CollectionData[] memory _collections) external pure returns (bytes32);

    /// @notice Returns balances of NFT deposited to the vault
    /// @param _collectionAddr NFT address
    /// @param _tokenId NFT's token ID
    /// @return amount amount of NFT deposited to the vault
    function balances(address _collectionAddr, uint256 _tokenId) external view returns (uint256 amount);

    /// @notice Get array of NFT addresses that are allowed to be deposited to the vault
    /// @dev Keep in mind that returned address(es) can be further restricted on token ID level
    /// @return collections array of NFT addresses that are allowed to be deposited to the vault
    function getAllowedCollections() external view returns (address[] memory collections);

    /// @return number of NFT addresses that are allowed to be deposited to the vault
    function getAllowedCollectionsLength() external view returns (uint256);

    /// @notice Get details of allowed collection
    /// @return struct with details of allowed collection
    function getAllowedCollectionData(address _collectionAddr) external view returns (CollectionData memory);

    /// @notice Validates type of collection (ERC721 or ERC1155)
    /// @dev It uses ERC165 to check interface support. If support can not be detected without doubt, user input is trusted.
    /// @param _collectionAddr NFT address
    /// @param _nftType NFT type, ERC721 or ERC1155
    /// @return nftType returns enum NftType as uint256
    function validateNftType(address _collectionAddr, NftType _nftType) external view returns (uint256 nftType);

    /// @notice Returns if true token can be deposited
    /// @param _collection NFT address
    /// @param _tokenId NFT token ID
    /// @return true if allowed
    function isTokenAllowed(address _collection, uint256 _tokenId) external view returns (bool);

    /// @notice Returns balance of token sent to the vault
    /// @dev Reads balance of tokens freshy sent to the vault
    /// @param _collection NFT address
    /// @param _tokenId NFT token ID
    /// @return balance of sent token, for ERC721 it's always 1
    function getSentTokenBalance(address _collection, uint256 _tokenId) external view returns (uint256);

    /// @notice Deposit NFT to vault
    /// @param _to address that gets minted ERC20 token
    /// @param _collection address of deposited NFT
    /// @param _tokenId token ID of deposited NFT
    /// @param _amount amount of deposited NFT, for ERC721 it's always 1
    /// @return amountMinted amount of minted ERC20 token
    function deposit(
        address _to,
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) external returns (uint256 amountMinted);

    /// @notice Deposit NFTs to vault
    /// @param _to address that gets minted ERC20 token
    /// @param _collection array of addresses of deposited NFTs
    /// @param _tokenId array of token IDs of deposited NFTs
    /// @param _amount array if amounts of deposited NFTs, for ERC721 it's always 1
    /// @return amountMinted amount of minted ERC20 token
    function depositBatch(
        address _to,
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount
    ) external returns (uint256 amountMinted);

    /// @notice Withdraw NFT from vault
    /// @param _to address that gets NFT
    /// @param _collection address of NFT to withdraw
    /// @param _tokenId token ID of NFT to withdraw
    /// @param _amount amount of NFT to withdraw, for ERC721 it's always 1
    /// @return amountBurned amount of burned ERC20
    function withdraw(
        address _to,
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) external returns (uint256 amountBurned);

    /// @notice Withdraw NFTs from vault
    /// @param _to address that gets NFT
    /// @param _collection array of addresses of NFTs to withdraw
    /// @param _tokenId array of token IDs of NFTs to withdraw
    /// @param _amount array of amounts of NFTs to withdraw, for ERC721 it's always 1
    /// @return amountBurned amount of burned ERC20
    function withdrawBatch(
        address _to,
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount
    ) external returns (uint256 amountBurned);

    /// @notice Allow anyone to withdraw tokens sent to this vault by accident
    ///         Only unsupported NFTs can be skimmed.
    /// @param _to address that gets NFT
    /// @param nftType NftType of skimmed NFT
    /// @param _collection address of NFT to skim
    /// @param _tokenId token ID of NFT to skim
    /// @param _amount amount of NFT to skim, for ERC721 it's always 1
    function skim(
        address _to,
        NftType nftType,
        address _collection,
        uint256 _tokenId,
        uint256 _amount
    ) external;
}
