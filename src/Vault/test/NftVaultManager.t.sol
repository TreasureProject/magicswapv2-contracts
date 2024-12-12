// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "lib/ERC721Mintable.sol";
import "lib/ERC1155Mintable.sol";

import "../INftVault.sol";
import "../NftVault.sol";
import "../NftVaultFactory.sol";
import "../NftVaultManager.sol";

contract NftVaultManagerTest is Test {
    NftVaultFactory public nftVaultFactory = new NftVaultFactory();
    NftVaultManager public nftVaultManager = new NftVaultManager();

    address user1 = address(1001);
    address user2 = address(1002);

    INftVault.CollectionData public collectionERC721all;
    INftVault.CollectionData public collectionERC1155all;

    INftVault.CollectionData[] public collections;

    event Deposit(address indexed to, address indexed collection, uint256 tokenId, uint256 amount);

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
    }

    function _getConfig() public returns (INftVault.CollectionData[] memory) {
        delete collections;

        // deploy fresh NFTs at every config request
        collectionERC721all.addr = address(new ERC721Mintable());
        collectionERC1155all.addr = address(new ERC1155Mintable());

        collections.push(collectionERC721all);
        collections.push(collectionERC1155all);

        return collections;
    }

    function testWithdrawBatch(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_amount > 1);
        vm.assume(_amount < type(uint128).max);

        INftVault.CollectionData[] memory _collections = _getConfig();
        NftVault nftVault = NftVault(address(nftVaultFactory.createVault(_collections)));

        ERC721Mintable(collections[0].addr).mint(address(nftVault), _tokenId);
        ERC1155Mintable(collections[1].addr).mint(address(nftVault), _tokenId, _amount);

        uint256 amountMinted721 = nftVault.deposit(user1, collections[0].addr, _tokenId, 1);

        assertEq(amountMinted721, 1 * nftVault.ONE());

        uint256 amountMinted1155 = nftVault.deposit(user2, collections[1].addr, _tokenId, _amount);

        assertEq(amountMinted1155, _amount * nftVault.ONE());

        address[] memory tempCollections = new address[](1);
        uint256[] memory tempTokenIds = new uint256[](1);
        uint256[] memory tempAmounts = new uint256[](1);

        tempCollections[0] = collections[1].addr;
        tempTokenIds[0] = _tokenId;
        tempAmounts[0] = 1;

        vm.prank(user1);
        nftVault.approve(address(nftVaultManager), type(uint256).max);
        vm.prank(user1);
        uint256 amountBurned =
            nftVaultManager.withdrawBatch(address(nftVault), tempCollections, tempTokenIds, tempAmounts);

        assertEq(amountBurned, amountMinted721);
        assertEq(nftVault.balanceOf(user1), 0);
        assertEq(ERC721Mintable(_collections[0].addr).ownerOf(_tokenId), address(nftVault));
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(user1, _tokenId), 1);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(address(nftVault), _tokenId), _amount - 1);

        uint256 transferAmount = amountMinted1155 - nftVault.ONE();
        tempCollections[0] = collections[1].addr;
        tempTokenIds[0] = _tokenId;
        tempAmounts[0] = _amount - 1;
        vm.prank(user2);
        nftVault.approve(address(nftVaultManager), type(uint256).max);
        vm.prank(user2);
        amountBurned = nftVaultManager.withdrawBatch(address(nftVault), tempCollections, tempTokenIds, tempAmounts);

        assertEq(amountBurned, transferAmount);
        assertEq(nftVault.balanceOf(user2), nftVault.ONE());
        assertEq(ERC721Mintable(_collections[0].addr).ownerOf(_tokenId), address(nftVault));
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(user2, _tokenId), _amount - 1);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(address(nftVault), _tokenId), 0);

        transferAmount = nftVault.ONE();
        tempCollections[0] = collections[0].addr;
        tempAmounts[0] = 1;

        vm.prank(user2);
        amountBurned = nftVaultManager.withdrawBatch(address(nftVault), tempCollections, tempTokenIds, tempAmounts);

        assertEq(amountBurned, transferAmount);
        assertEq(nftVault.balanceOf(user2), 0);
        assertEq(ERC721Mintable(_collections[0].addr).ownerOf(_tokenId), user2);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(user1, _tokenId), 1);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(user2, _tokenId), _amount - 1);
        assertEq(ERC1155Mintable(_collections[1].addr).balanceOf(address(nftVault), _tokenId), 0);
    }

    function testDepositBatch(uint256 _tokenId, uint256 _amount) public {
        INftVault.CollectionData[] memory _collections = _getConfig();
        NftVault vault = NftVault(address(nftVaultFactory.createVault(_collections)));

        for (uint256 i = 0; i < _collections.length; i++) {
            if (!collections[i].allowAllIds) {
                // if not all allowed, take random tokenId that is allowed with fuzzing for randomness
                _tokenId = collections[i].tokenIds[_tokenId % collections[i].tokenIds.length];
            }

            if (collections[i].nftType == INftVault.NftType.ERC721) {
                _amount = 1;
                ERC721Mintable(collections[i].addr).mint(user1, _tokenId);

                vm.prank(user1);
                ERC721Mintable(collections[i].addr).setApprovalForAll(address(nftVaultManager), true);
            } else {
                ERC1155Mintable(collections[i].addr).mint(user1, _tokenId, _amount);
                vm.prank(user1);
                ERC1155Mintable(collections[i].addr).setApprovalForAll(address(nftVaultManager), true);
            }

            uint256 balancesBefore = vault.balances(collections[i].addr, _tokenId);
            uint256 erc20balanceBefore = vault.balanceOf(user1);

            vm.expectEmit(true, true, true, true);
            emit Deposit(user1, collections[i].addr, _tokenId, _amount);

            address[] memory tempCollections = new address[](1);
            uint256[] memory tempTokenIds = new uint256[](1);
            uint256[] memory tempAmounts = new uint256[](1);
            tempCollections[0] = collections[i].addr;
            tempTokenIds[0] = _tokenId;
            tempAmounts[0] = _amount;

            vm.prank(user1);
            uint256 amountMinted =
                nftVaultManager.depositBatch(address(vault), tempCollections, tempTokenIds, tempAmounts);

            assertEq(amountMinted / vault.ONE(), _amount);
            assertEq(vault.balanceOf(user1), erc20balanceBefore + amountMinted);
            assertEq(vault.balances(collections[i].addr, _tokenId), balancesBefore + _amount);
        }
    }
}
