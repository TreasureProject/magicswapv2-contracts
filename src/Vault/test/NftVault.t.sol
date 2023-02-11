// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "lib/ERC721Mintable.sol";
import "lib/ERC1155Mintable.sol";

import "../INftVault.sol";
import "../NftVault.sol";
import "../NftVaultFactory.sol";

contract NftVaultTest is Test {
    NftVaultFactory public nftVaultFactory = new NftVaultFactory();

    address user1 = address(1001);
    address user2 = address(1002);
    address owner = address(1003);
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
    event AllowedDepositWithdraw(address wallet);
    event DisallowedDepositWithdraw(address wallet);

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

    function _deployTestVault(uint256 configId) public returns (
        NftVault vault,
        INftVault.CollectionData[] memory _collections
    ) {
        _collections = _getConfig(configId);
        vault = NftVault(address(nftVaultFactory.createVault(_collections)));
    }

    function _getAddressesFromCollections(INftVault.CollectionData[] memory _collections)
        public
        view
        returns (address[] memory addresses)
    {
        addresses = new address[](_collections.length);

        for (uint256 i = 0; i < collections.length; i++) {
             addresses[i] = _collections[i].addr;
        }
    }

    function testInitReverts() public {
        NftVault nftVault;

        delete collections;
        vm.expectRevert(INftVault.InvalidCollections.selector);
        nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        delete collections;
        collections.push(collectionAllWithTokenIds);
        vm.expectRevert(INftVault.TokenIdsMustBeEmpty.selector);
        nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        delete collections;
        collections.push(collectionERC721allWrongNftType);
        vm.expectRevert(INftVault.ExpectedERC721.selector);
        nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        delete collections;
        collections.push(collectionERC1155allWrongNftType);
        vm.expectRevert(INftVault.ExpectedERC1155.selector);
        nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        delete collections;
        collections.push(collectionERC721allowedMissingTokens);
        vm.expectRevert(INftVault.MissingTokenIds.selector);
        nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        delete collections;
        collections.push(collectionERC721allowedUnsortedTokens);
        vm.expectRevert(INftVault.TokenIdsMustBeSorted.selector);
        nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        delete collections;
        collections.push(collectionERC721allowedDuplicatedTokens);
        vm.expectRevert(INftVault.TokenIdAlreadySet.selector);
        nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        nftVault = new NftVault("name", "symbol");

        assertEq(nftVault.VAULT_HASH(), bytes32(0));
        assertEq(nftVault.getAllowedCollections(), new address[](0));
        assertEq(nftVault.getAllowedCollectionsLength(), 0);
        assertEq(nftVault.ONE(), 10**nftVault.decimals());
        assertEq(nftVault.ONE(), 1e18);
        assertEq(nftVault.name(), "name");
        assertEq(nftVault.symbol(), "symbol");
    }

    function testInitStorage() public {
        for (uint256 configId = 0; configId < 8; configId++) {
            console2.log("configId", configId);
            INftVault.CollectionData[] memory _collections = _getConfig(configId);
            NftVault vault = NftVault(address(nftVaultFactory.createVault(_collections)));

            assertEq(vault.hashVault(_collections), vault.VAULT_HASH());
            assertEq(vault.getAllowedCollections(), _getAddressesFromCollections(_collections));
            assertEq(vault.getAllowedCollectionsLength(), _collections.length);

            for (uint256 i = 0; i < _collections.length; i++) {
                INftVault.CollectionData memory c = vault.getAllowedCollectionData(_collections[i].addr);
                assertEq(c.addr, _collections[i].addr);
                assertEq(uint256(c.nftType), uint256(_collections[i].nftType));
                assertEq(c.allowAllIds, _collections[i].allowAllIds);
                assertEq(c.tokenIds, _collections[i].tokenIds);

                for (uint256 j = 0; j < _collections[i].tokenIds.length; j++) {
                    assertTrue(vault.isTokenAllowed(_collections[i].addr, _collections[i].tokenIds[j]));
                }
            }

            vm.expectRevert(INftVault.Initialized.selector);
            vault.init(_collections);
        }
    }

    function testValidateNftType() public {
        NftVault nftVault = new NftVault("name", "symbol");

        assertEq(
            uint256(nftVault.validateNftType(collectionERC721all.addr, collectionERC721all.nftType)),
            uint256(collectionERC721all.nftType)
        );

        assertEq(
            uint256(nftVault.validateNftType(collectionERC1155all.addr, collectionERC1155all.nftType)),
            uint256(collectionERC1155all.nftType)
        );

        assertEq(
            uint256(nftVault.validateNftType(collectionERC721allowed.addr, collectionERC721allowed.nftType)),
            uint256(collectionERC721allowed.nftType)
        );

        assertEq(
            uint256(nftVault.validateNftType(collectionERC1155allowed.addr, collectionERC1155allowed.nftType)),
            uint256(collectionERC1155allowed.nftType)
        );

        vm.expectRevert(INftVault.ExpectedERC721.selector);
        nftVault.validateNftType(collectionERC721allWrongNftType.addr, collectionERC721allWrongNftType.nftType);

        vm.expectRevert(INftVault.ExpectedERC1155.selector);
        nftVault.validateNftType(collectionERC1155allWrongNftType.addr, collectionERC1155allWrongNftType.nftType);

        // test hypothetical contract that supports ERC721 and ERC1155
        vm.mockCall(erc721and1155, abi.encodeCall(ERC165.supportsInterface, (type(IERC721).interfaceId)), abi.encode(true));
        vm.mockCall(erc721and1155, abi.encodeCall(ERC165.supportsInterface, (type(IERC1155).interfaceId)), abi.encode(true));
        assertEq(
            uint256(nftVault.validateNftType(erc721and1155, INftVault.NftType.ERC721)),
            uint256(INftVault.NftType.ERC721)
        );
        assertEq(
            uint256(nftVault.validateNftType(erc721and1155, INftVault.NftType.ERC1155)),
            uint256(INftVault.NftType.ERC1155)
        );
        vm.clearMockedCalls();
    }

    function testIsTokenAllowed(address collectionAddr, uint256 tokenId) public {
        delete collections;
        INftVault.CollectionData memory config = INftVault.CollectionData({
            addr: address(new ERC721Mintable()),
            nftType: INftVault.NftType.ERC721,
            allowAllIds: false,
            tokenIds: erc721tokenIds
        });
        collections.push(config);
        NftVault nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        vm.assume(collectionAddr != config.addr);

        for (uint256 i = 0; i < erc721tokenIds.length; i++) {
            vm.assume(tokenId != erc721tokenIds[i]);
        }

        assertFalse(nftVault.isTokenAllowed(collectionAddr, tokenId));
    }

    function testGetSentTokenBalance(uint256 tokenId, uint256 amount) public {
        delete collections;
        collections.push(collectionERC721all);
        collections.push(collectionERC1155all);
        NftVault nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        ERC721Mintable erc721 = ERC721Mintable(collectionERC721all.addr);
        ERC1155Mintable erc1155 = ERC1155Mintable(collectionERC1155all.addr);

        erc721.mint(user1, tokenId);
        vm.prank(user1);
        erc721.transferFrom(user1, address(nftVault), tokenId);
        assertEq(nftVault.getSentTokenBalance(address(erc721), tokenId), 1);

        erc1155.mint(user1, tokenId, amount);
        vm.prank(user1);
        erc1155.safeTransferFrom(
            user1,
            address(nftVault),
            tokenId,
            amount,
            bytes("")
        );
        assertEq(nftVault.getSentTokenBalance(address(erc1155), tokenId), amount);
    }

    function testDepositRevert(uint256 _tokenId, uint256 _amount) public {
        uint256 otherTokenId = 56464987645;
        vm.assume(_tokenId != otherTokenId);
        vm.assume(_amount < type(uint256).max);

        delete collections;
        collections.push(collectionERC721all);
        collections.push(collectionERC1155all);
        NftVault nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        vm.expectRevert(INftVault.DisallowedToken.selector);
        nftVault.deposit(
            user1,
            address(5566),
            _tokenId,
            1
        );

        ERC721Mintable(collections[0].addr).mint(user2, otherTokenId);

        vm.expectRevert(INftVault.WrongAmount.selector);
        nftVault.deposit(
            user1,
            collections[0].addr,
            otherTokenId,
            1
        );

        ERC721Mintable(collections[0].addr).mint(address(nftVault), _tokenId);
        assertEq(nftVault.getSentTokenBalance(collections[0].addr, _tokenId), 1);

        vm.expectRevert(INftVault.WrongAmount.selector);
        nftVault.deposit(
            user1,
            collections[0].addr,
            _tokenId,
            0
        );

        ERC1155Mintable(collections[1].addr).mint(address(nftVault), _tokenId, _amount);
        assertEq(nftVault.getSentTokenBalance(collections[1].addr, _tokenId), _amount);

        vm.expectRevert(INftVault.WrongAmount.selector);
        nftVault.deposit(
            user1,
            collections[1].addr,
            _tokenId,
            _amount + 1
        );
    }

    function testDepositAllConfigs(uint256 _tokenId, uint256 _amount) public {
        for (uint256 configId = 0; configId < 8; configId++) {
            console2.log("configId", configId);
            INftVault.CollectionData[] memory _collections = _getConfig(configId);
            NftVault vault = NftVault(address(nftVaultFactory.createVault(_collections)));

            for (uint256 i = 0; i < _collections.length; i++) {
                if (!collections[i].allowAllIds) {
                    // if not all allowed, take random tokenId that is allowed with fuzzing for randomness
                    _tokenId = collections[i].tokenIds[_tokenId % collections[i].tokenIds.length];
                }

                if (collections[i].nftType == INftVault.NftType.ERC721) {
                    _amount = 1;
                    ERC721Mintable(collections[i].addr).mint(address(vault), _tokenId);
                } else {
                    ERC1155Mintable(collections[i].addr).mint(address(vault), _tokenId, _amount);
                }

                uint256 balancesBefore = vault.balances(collections[i].addr, _tokenId);
                uint256 erc20balanceBefore = vault.balanceOf(user1);

                vm.expectEmit(true, true, true, true);
                emit Deposit(user1, collections[i].addr, _tokenId, _amount);
                uint256 amountMinted = vault.deposit(
                    user1,
                    collections[i].addr,
                    _tokenId,
                    _amount
                );

                assertEq(amountMinted / vault.ONE(), _amount);
                assertEq(vault.balanceOf(user1), erc20balanceBefore + amountMinted);
                assertEq(vault.balances(collections[i].addr, _tokenId), balancesBefore + _amount);
            }
        }
    }

    function testDepositBatchWithdrawBatch(uint256 _tokenId, uint256[] memory _amounts) public {
        delete collections;
        collections.push(collectionERC721all);
        collections.push(collectionERC1155all);
        NftVault nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        vm.assume(_amounts.length > 10);

        assertEq(nftVault.balanceOf(user1), 0);

        address[] memory collectionBatch = new address[](10);
        uint256[] memory tokenIdBatch = new uint256[](10);
        uint256[] memory amountBatch = new uint256[](10);
        uint256 expectedAmountMinted = 0;

        for (uint256 i = 0; i < 10; i++) {
            vm.assume(_tokenId < type(uint64).max);
            uint256 tokenId = _tokenId + i;

            vm.assume(_amounts[i] > 0);
            vm.assume(_amounts[i] < type(uint64).max);
            uint256 amount = _amounts[i];

            if (i % 2 == 0) {
                ERC721Mintable(collections[0].addr).mint(address(nftVault), tokenId);
                collectionBatch[i] = collections[0].addr;
                tokenIdBatch[i] = tokenId;
                amountBatch[i] = 1;
            } else {
                ERC1155Mintable(collections[1].addr).mint(address(nftVault), tokenId, amount);
                collectionBatch[i] = collections[1].addr;
                tokenIdBatch[i] = tokenId;
                amountBatch[i] = amount;
            }

            expectedAmountMinted += amountBatch[i];
        }

        uint256 amountMinted = nftVault.depositBatch(user1, collectionBatch, tokenIdBatch, amountBatch);

        assertEq(amountMinted / nftVault.ONE(), expectedAmountMinted);
        assertEq(nftVault.balanceOf(user1), expectedAmountMinted * nftVault.ONE());
        assertEq(nftVault.balanceOf(user1), amountMinted);

        for (uint256 i = 0; i < 10; i++) {
            assertEq(nftVault.balances(collectionBatch[i], tokenIdBatch[i]), amountBatch[i]);
        }

        vm.prank(user1);
        nftVault.transfer(address(nftVault), amountMinted);

        uint256 amountBurned = nftVault.withdrawBatch(user2, collectionBatch, tokenIdBatch, amountBatch);

        assertEq(amountBurned, amountMinted);
        assertEq(nftVault.balanceOf(user1), 0);
        assertEq(nftVault.balanceOf(user2), 0);

        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 == 0) {
                assertEq(ERC721Mintable(collections[0].addr).ownerOf(tokenIdBatch[i]), user2);
            } else {
                assertEq(ERC1155Mintable(collections[1].addr).balanceOf(user2, tokenIdBatch[i]), amountBatch[i]);
            }
            assertEq(nftVault.balances(collectionBatch[i], tokenIdBatch[i]), 0);
        }
    }

    function testWithdrawRevert(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint128).max);

        INftVault.CollectionData[] memory _collections = _getConfig(4);
        NftVault nftVault = NftVault(address(nftVaultFactory.createVault(_collections)));

        ERC721Mintable(collections[0].addr).mint(address(nftVault), _tokenId);
        ERC1155Mintable(collections[1].addr).mint(address(nftVault), _tokenId, _amount);

        uint256 amountMinted721 = nftVault.deposit(
            user1,
            collections[0].addr,
            _tokenId,
            1
        );

        assertEq(amountMinted721, 1 * nftVault.ONE());

        uint256 amountMinted1155 = nftVault.deposit(
            user1,
            collections[1].addr,
            _tokenId,
            _amount
        );

        assertEq(amountMinted1155, _amount * nftVault.ONE());

        vm.expectRevert(INftVault.WrongAmount.selector);
        nftVault.withdraw(
            user1,
            collections[0].addr,
            _tokenId,
            0
        );

        vm.expectRevert(INftVault.WrongAmount.selector);
        nftVault.withdraw(
            user1,
            collections[1].addr,
            _tokenId,
            0
        );

        vm.expectRevert(INftVault.WrongAmount.selector);
        nftVault.withdraw(
            user1,
            collections[0].addr,
            _tokenId,
            2
        );

        vm.expectRevert(INftVault.WrongAmount.selector);
        nftVault.withdraw(
            user1,
            collections[1].addr,
            _tokenId,
            _amount + 1
        );

        vm.expectRevert("ERC20: burn amount exceeds balance");
        nftVault.withdraw(
            user1,
            collections[0].addr,
            _tokenId,
            1
        );

        vm.expectRevert("ERC20: burn amount exceeds balance");
        nftVault.withdraw(
            user1,
            collections[1].addr,
            _tokenId,
            _amount
        );
    }

    function testWithdraw(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_amount > 1);
        vm.assume(_amount < type(uint128).max);

        INftVault.CollectionData[] memory _collections = _getConfig(4);
        NftVault nftVault = NftVault(address(nftVaultFactory.createVault(_collections)));

        ERC721Mintable(collections[0].addr).mint(address(nftVault), _tokenId);
        ERC1155Mintable(collections[1].addr).mint(address(nftVault), _tokenId, _amount);

        uint256 amountMinted721 = nftVault.deposit(
            user1,
            collections[0].addr,
            _tokenId,
            1
        );

        assertEq(amountMinted721, 1 * nftVault.ONE());

        uint256 amountMinted1155 = nftVault.deposit(
            user2,
            collections[1].addr,
            _tokenId,
            _amount
        );

        assertEq(amountMinted1155, _amount * nftVault.ONE());

        vm.prank(user1);
        nftVault.transfer(address(nftVault), amountMinted721);

        uint256 amountBurned = nftVault.withdraw(
            user1,
            collections[1].addr,
            _tokenId,
            1
        );

        assertEq(amountBurned, amountMinted721);
        assertEq(nftVault.balanceOf(user1), 0);
        assertEq(ERC721Mintable(_collections[0].addr).ownerOf(_tokenId), address(nftVault));
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(user1, _tokenId), 1);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(address(nftVault), _tokenId), _amount - 1);

        uint256 transferAmount = amountMinted1155 - nftVault.ONE();
        vm.prank(user2);
        nftVault.transfer(address(nftVault), transferAmount);

        amountBurned = nftVault.withdraw(
            user2,
            collections[1].addr,
            _tokenId,
            _amount - 1
        );

        assertEq(amountBurned, transferAmount);
        assertEq(nftVault.balanceOf(user2), nftVault.ONE());
        assertEq(ERC721Mintable(_collections[0].addr).ownerOf(_tokenId), address(nftVault));
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(user2, _tokenId), _amount - 1);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(address(nftVault), _tokenId), 0);

        transferAmount = nftVault.ONE();
        vm.prank(user2);
        nftVault.transfer(address(nftVault), transferAmount);

        amountBurned = nftVault.withdraw(
            user2,
            collections[0].addr,
            _tokenId,
            1
        );

        assertEq(amountBurned, transferAmount);
        assertEq(nftVault.balanceOf(user2), 0);
        assertEq(ERC721Mintable(_collections[0].addr).ownerOf(_tokenId), user2);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(user1, _tokenId), 1);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(user2, _tokenId), _amount - 1);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(address(nftVault), _tokenId), 0);
    }

    function testWithdrawLast(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_amount > 1);
        vm.assume(_amount < type(uint128).max);

        INftVault.CollectionData[] memory _collections = _getConfig(4);
        NftVault nftVault = NftVault(address(nftVaultFactory.createVault(_collections)));

        ERC721Mintable(collections[0].addr).mint(address(nftVault), _tokenId);
        ERC1155Mintable(collections[1].addr).mint(address(nftVault), _tokenId, _amount);

        address[] memory lastCollections = new address[](2);
        uint256[] memory lastTokenIds = new uint256[](2);
        uint256[] memory lastAmounts = new uint256[](2);

        lastCollections[0] = collections[0].addr;
        lastCollections[1] = collections[1].addr;

        lastTokenIds[0] = _tokenId;
        lastTokenIds[1] = _tokenId;

        lastAmounts[0] = 1;
        lastAmounts[1] = _amount;

        uint256 amountMinted = nftVault.depositBatch(
            user1,
            lastCollections,
            lastTokenIds,
            lastAmounts
        );

        assertEq(amountMinted, (_amount + 1) * nftVault.ONE());
        assertEq(nftVault.balanceOf(user1), amountMinted);

        vm.startPrank(user1);
        nftVault.transfer(owner, nftVault.UNIV2_MINIMUM_LIQUIDITY());
        nftVault.transfer(address(nftVault), nftVault.balanceOf(user1));
        vm.stopPrank();

        nftVault.withdrawBatch(
            user1,
            lastCollections,
            lastTokenIds,
            lastAmounts
        );

        assertEq(ERC721Mintable(collections[0].addr).ownerOf(_tokenId), user1);
        assertEq(ERC1155Mintable(collections[1].addr).balanceOf(user1, _tokenId), _amount);
        assertEq(nftVault.balanceOf(user1), 0);
        assertEq(nftVault.balanceOf(address(nftVault)), 0);
    }

    function testSkim(uint256 tokenId, uint256 amount) public {
        delete collections;
        collections.push(collectionERC721all);
        collections.push(collectionERC1155all);
        NftVault nftVault = NftVault(address(nftVaultFactory.createVault(collections)));

        ERC721Mintable erc721 = ERC721Mintable(collectionERC721all.addr);
        ERC1155Mintable erc1155 = ERC1155Mintable(collectionERC1155all.addr);

        assertTrue(nftVault.isTokenAllowed(address(erc721), tokenId));
        assertEq(erc721.balanceOf(user2), 0);
        erc721.mint(user1, tokenId);
        vm.prank(user1);
        erc721.transferFrom(user1, address(nftVault), tokenId);
        vm.prank(user2);
        vm.expectRevert(INftVault.MustBeDisallowedToken.selector);
        nftVault.skim(
            user2,
            INftVault.NftType.ERC721,
            address(erc721),
            tokenId,
            1
        );

        assertTrue(nftVault.isTokenAllowed(address(erc1155), tokenId));
        assertEq(erc1155.balanceOf(user2, tokenId), 0);
        erc1155.mint(user1, tokenId, amount);
        vm.prank(user1);
        erc1155.safeTransferFrom(
            user1,
            address(nftVault),
            tokenId,
            amount,
            bytes("")
        );
        vm.prank(user2);
        vm.expectRevert(INftVault.MustBeDisallowedToken.selector);
        nftVault.skim(
            user2,
            INftVault.NftType.ERC1155,
            address(erc1155),
            tokenId,
            amount
        );
        assertEq(erc1155.balanceOf(user2, tokenId), 0);

        ERC721Mintable newErc721 = new ERC721Mintable();

        newErc721.mint(address(nftVault), tokenId);
        assertFalse(nftVault.isTokenAllowed(address(newErc721), tokenId));
        vm.prank(user2);
        nftVault.skim(
            user2,
            INftVault.NftType.ERC721,
            address(newErc721),
            tokenId,
            amount
        );
        assertEq(newErc721.balanceOf(user2), 1);

        ERC1155Mintable newErc1155 = new ERC1155Mintable();

        newErc1155.mint(address(nftVault), tokenId, amount);
        assertFalse(nftVault.isTokenAllowed(address(newErc1155), tokenId));
        vm.prank(user2);
        nftVault.skim(
            user2,
            INftVault.NftType.ERC1155,
            address(newErc1155),
            tokenId,
            amount
        );
        assertEq(newErc1155.balanceOf(user2, tokenId), amount);
    }
}
