// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Vault contract for wrapping NFTs (ERC721/ERC1155) to ERC20
interface INftVault {
    enum NftType {
        ERC721,
        ERC1155
    }

    /// @notice Vault configuration struct that specifies which NFTs are accepted in vault.
    /// @param addr address of nft contract
    /// @param nftType standard that NFT supports { ERC721, ERC1155 }
    /// @param allowAllIds if true, all tokens are allowed in the vault. If false, tokenIds must be
    ///        listed one by one.
    /// @param tokenIds list of tokens supported by vault. If allowAllIds is true, list must be empty.
    struct CollectionData {
        address addr;
        NftType nftType;
        bool allowAllIds;
        uint256[] tokenIds;
    }

    /// @notice Struct for allowed tokens. Stores data in an optimized way to read it in vault.
    /// @param tokenIds mapping from tokenid to is-allowed
    /// @param tokenIdList list of all tokens that are allowed
    /// @param allowAllIds if true, all tokens are allowed
    struct AllowedTokenIds {
        mapping(uint256 => bool) tokenIds;
        uint256[] tokenIdList;
        bool allowAllIds;
    }

    /// @notice Emitted during initiation when collection added to allowed list
    /// @param collection collection details
    event CollectionAllowed(CollectionData collection);

    /// @notice Emitted on depositing NFT to vault
    /// @param to address that gets vault ERC20 tokens
    /// @param collection NFT address that is deposited
    /// @param tokenId token id that is deposited
    /// @param amount amount of token that is deposited, for ERC721 always 1
    event Deposit(address indexed to, address indexed collection, uint256 tokenId, uint256 amount);

    /// @notice Emitted on withdrawing NFT from vault
    /// @param to address that gets withdrawn NFTs
    /// @param collection NFT address that is withdrawn
    /// @param tokenId token id that is withdrawn
    /// @param amount amount of token that is withdrawn, for ERC721 always 1
    event Withdraw(address indexed to, address indexed collection, uint256 tokenId, uint256 amount);

    /// @dev Contract is already initialized
    error Initialized();
    /// @dev Collection data is empty
    error InvalidCollections();
    /// @dev Collection already added
    error DuplicateCollection();
    /// @dev Token id is listed twice in CollectionData.tokenIds array
    error TokenIdAlreadySet();
    /// @dev Token ids in CollectionData.tokenIds array are not sorted
    error TokenIdsMustBeSorted();
    /// @dev ERC165 suggests that NFT is supporting ERC721 but ERC1155 is claimed
    error ExpectedERC721();
    /// @dev ERC165 suggests that NFT is supporting ERC1155 but ERC721 is claimed
    error ExpectedERC1155();
    /// @dev Collection does not support all token IDs however list of IDs is empty.
    ///      CollectionData.tokenIds is empty and CollectionData.allowAllIds is false.
    error MissingTokenIds();
    /// @dev CollectionData.tokenIds is not empty however Collection supports all token IDs.
    error TokenIdsMustBeEmpty();
    /// @dev Token is not allowed in vault
    error DisallowedToken();
    /// @dev Token amount is invalid eg. amount == 0
    error WrongAmount();
    /// @dev Token amount is invalid for ERC721, amount != 1
    error WrongERC721Amount();
    /// @dev Trying to interact with token that does not support ERC721 nor ERC1155
    error UnsupportedNft();
    /// @dev Token is allowed in vault but must not be
    error MustBeDisallowedToken();

    /// @notice value of 1 token, including decimals
    function ONE() external view returns (uint256);

    /// @notice amount of token required for last NFT to be redeemed
    function LAST_NFT_AMOUNT() external view returns (uint256);

    /// @notice unique id of the vault generated using its configuration
    function VAULT_HASH() external view returns (bytes32);

    /// @notice Initialize Vault with collection config
    /// @dev Called by factory during deployment
    /// @param collections struct array of allowed collections and token IDs
    function init(CollectionData[] memory collections) external;

    /// @notice Returns hash of vault configuration
    /// @param collections struct array of allowed collections and token IDs
    /// @return configuration hash
    function hashVault(CollectionData[] memory collections) external pure returns (bytes32);

    /// @notice Returns balances of NFT deposited to the vault
    /// @param collectionAddr NFT address
    /// @param tokenId NFT's token ID
    /// @return amount amount of NFT deposited to the vault
    function balances(address collectionAddr, uint256 tokenId) external view returns (uint256 amount);

    /// @notice Get array of NFT addresses that are allowed to be deposited to the vault
    /// @dev Keep in mind that returned address(es) can be further restricted on token ID level
    /// @return collections array of NFT addresses that are allowed to be deposited to the vault
    function getAllowedCollections() external view returns (address[] memory collections);

    /// @return number of NFT addresses that are allowed to be deposited to the vault
    function getAllowedCollectionsLength() external view returns (uint256);

    /// @notice Get details of allowed collection
    /// @return struct with details of allowed collection
    function getAllowedCollectionData(address collectionAddr) external view returns (CollectionData memory);

    /// @notice Validates type of collection (ERC721 or ERC1155)
    /// @dev It uses ERC165 to check interface support. If support can not be detected without doubt, user input is trusted.
    /// @param collectionAddr NFT address
    /// @param nftType NFT type, ERC721 or ERC1155
    /// @return validatedNftType returns validated enum NftType as uint256
    function validateNftType(address collectionAddr, NftType nftType)
        external
        view
        returns (uint256 validatedNftType);

    /// @notice Returns if true token can be deposited
    /// @param collection NFT address
    /// @param tokenId NFT token ID
    /// @return true if allowed
    function isTokenAllowed(address collection, uint256 tokenId) external view returns (bool);

    /// @notice Returns balance of token sent to the vault
    /// @dev Reads balance of tokens freshy sent to the vault
    /// @param collection NFT address
    /// @param tokenId NFT token ID
    /// @return balance of sent token, for ERC721 it's always 1
    function getSentTokenBalance(address collection, uint256 tokenId) external view returns (uint256);

    /// @notice Deposit NFT to vault
    /// @dev This low-level function should be called from a contract which performs important safety checks
    /// @param to address that gets minted ERC20 token
    /// @param collection address of deposited NFT
    /// @param tokenId token ID of deposited NFT
    /// @param amount amount of deposited NFT, for ERC721 it's always 1
    /// @return amountMinted amount of minted ERC20 token
    function deposit(address to, address collection, uint256 tokenId, uint256 amount)
        external
        returns (uint256 amountMinted);

    /// @notice Deposit NFTs to vault
    /// @dev This low-level function should be called from a contract which performs important safety checks
    /// @param to address that gets minted ERC20 token
    /// @param collection array of addresses of deposited NFTs
    /// @param tokenId array of token IDs of deposited NFTs
    /// @param amount array if amounts of deposited NFTs, for ERC721 it's always 1
    /// @return amountMinted amount of minted ERC20 token
    function depositBatch(address to, address[] memory collection, uint256[] memory tokenId, uint256[] memory amount)
        external
        returns (uint256 amountMinted);

    /// @notice Withdraw NFT from vault
    /// @dev This low-level function should be called from a contract which performs important safety checks
    /// @param to address that gets NFT
    /// @param collection address of NFT to withdraw
    /// @param tokenId token ID of NFT to withdraw
    /// @param amount amount of NFT to withdraw, for ERC721 it's always 1
    /// @return amountBurned amount of burned ERC20
    function withdraw(address to, address collection, uint256 tokenId, uint256 amount)
        external
        returns (uint256 amountBurned);

    /// @notice Withdraw NFTs from vault
    /// @dev This low-level function should be called from a contract which performs important safety checks
    /// @param to address that gets NFT
    /// @param collection array of addresses of NFTs to withdraw
    /// @param tokenId array of token IDs of NFTs to withdraw
    /// @param amount array of amounts of NFTs to withdraw, for ERC721 it's always 1
    /// @return amountBurned amount of burned ERC20
    function withdrawBatch(address to, address[] memory collection, uint256[] memory tokenId, uint256[] memory amount)
        external
        returns (uint256 amountBurned);

    /// @notice Allow anyone to withdraw tokens sent to this vault by accident
    ///         Only unsupported NFTs can be skimmed.
    /// @param to address that gets NFT
    /// @param nftType NftType of skimmed NFT
    /// @param collection address of NFT to skim
    /// @param tokenId token ID of NFT to skim
    /// @param amount amount of NFT to skim, for ERC721 it's always 1
    function skim(address to, NftType nftType, address collection, uint256 tokenId, uint256 amount) external;
}
