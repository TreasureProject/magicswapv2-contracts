// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "lib/ERC721Mintable.sol";
import "lib/ERC1155Mintable.sol";

import "./mock/WETH.sol";
import "../MagicSwapV2Router.sol";
import "../../UniswapV2/core/UniswapV2Factory.sol";
import "../../Vault/NftVaultFactory.sol";

contract MagicSwapV2RouterTest is Test {
    WETH weth;
    UniswapV2Factory factory;
    MagicSwapV2Router magicSwapV2Router;
    NftVaultFactory nftVaultFactory;
    ERC721Mintable nft1;
    ERC1155Mintable nft2;

    uint256 ONE;

    address user1 = address(10000001);
    address user2 = address(10000002);
    address user3 = address(10000003);
    address user4 = address(10000004);

    address protocolFeeBeneficiary = address(10000005);

    INftVault.CollectionData public collectionERC721all;
    INftVault.CollectionData public collectionERC1155all;
    INftVault.CollectionData[] public collections1;
    INftVault.CollectionData[] public collections2;

    INftVault vault1;
    INftVault vault2;

    address[] public collectionArray;
    uint256[] public tokenIdArray;
    uint256[] public amountArray;

    address[] public collectionArray1;
    uint256[] public tokenIdArray1;
    uint256[] public amountArray1;

    function setUp() public {
        weth = new WETH();

        factory = new UniswapV2Factory(0, 30, protocolFeeBeneficiary);

        magicSwapV2Router = new MagicSwapV2Router(address(factory), address(weth));

        nftVaultFactory = new NftVaultFactory();

        collectionERC721all = INftVault.CollectionData({
            addr: address(new ERC721Mintable()),
            nftType: INftVault.NftType.ERC721,
            allowAllIds: true,
            tokenIds: new uint256[](0)
        });

        collections1.push(collectionERC721all);
        vault1 = nftVaultFactory.createVault(collections1, address(0));
        nft1 = ERC721Mintable(collectionERC721all.addr);

        collectionERC1155all = INftVault.CollectionData({
            addr: address(new ERC1155Mintable()),
            nftType: INftVault.NftType.ERC1155,
            allowAllIds: true,
            tokenIds: new uint256[](0)
        });

        collections2.push(collectionERC721all);
        collections2.push(collectionERC1155all);
        vault2 = nftVaultFactory.createVault(collections2, address(0));
        nft2 = ERC1155Mintable(collectionERC1155all.addr);

        ONE = vault1.ONE();
    }

    function _dealWeth(address _user, uint256 _amount) public {
        vm.deal(_user, _amount);
        vm.prank(_user);
        weth.deposit{value: _amount}();
        vm.prank(_user);
        weth.approve(address(magicSwapV2Router), _amount);
    }

    function _copyStorage() public view returns (
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount
    ) {
        _collection = collectionArray;
        _tokenId = tokenIdArray;
        _amount = amountArray;
    }

    function _mintTokens(address _user) public returns (
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount
    ) {
        (_collection, _tokenId, _amount) = _copyStorage();

        for (uint256 i = 0; i < _collection.length; i++) {
            if (_collection[i] == address(nft1)) {
                nft1.mint(_user, _tokenId[i]);
                vm.prank(_user);
                nft1.setApprovalForAll(address(magicSwapV2Router), true);
            } else {
                nft2.mint(_user, _tokenId[i], _amount[i]);
                vm.prank(_user);
                nft2.setApprovalForAll(address(magicSwapV2Router), true);
            }
        }
    }

    function _checkNftBalances(
        address[] memory _collection,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        address _owner
    ) public {
        for (uint256 i = 0; i < _collection.length; i++) {
            if (_collection[i] == address(nft1)) {
                assertEq(nft1.ownerOf(_tokenId[i]), _owner);
            } else {
                assertEq(nft2.balanceOf(_owner, _tokenId[i]), _amount[i]);
            }
        }
    }

    function _checkERC20Balances(
        address[] memory _collection,
        uint256[] memory,
        uint256[] memory _amount,
        address _vault,
        address _owner,
        uint256 _prevBalance
    ) public {
        uint256 totalAmount;

        for (uint256 i = 0; i < _collection.length; i++) {
            totalAmount += _amount[i];
        }

        assertEq(IERC20(_vault).balanceOf(_owner), totalAmount * ONE + _prevBalance);
    }

    function testDepositWithdrawVault(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_tokenId < type(uint256).max - 50);
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint64).max);

        // deposit 1
        collectionArray = [address(nft1), address(nft1), address(nft1), address(nft1)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        amountArray = [uint256(1), 1, 1, 1];

        (
            address[] memory _collection1,
            uint256[] memory _tokenId1,
            uint256[] memory _amount1
        ) = _mintTokens(user1);

        vm.prank(user1);
        uint256 amountMinted1 = magicSwapV2Router.depositVault(
            _collection1,
            _tokenId1,
            _amount1,
            vault1,
            user1
        );

        assertEq(amountMinted1, magicSwapV2Router.nftAmountToERC20(_amount1));

        _checkNftBalances(_collection1, _tokenId1, _amount1, address(vault1));
        _checkERC20Balances(_collection1, _tokenId1, _amount1, address(vault1), user1, 0);

        // deposit 2
        collectionArray = [address(nft1), address(nft1), address(nft2), address(nft2)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        amountArray = [uint256(1), 1, _amount++, _amount++];

        (
            address[] memory _collection2,
            uint256[] memory _tokenId2,
            uint256[] memory _amount2
        ) = _mintTokens(user2);

        vm.prank(user2);
        uint256 amountMinted2 = magicSwapV2Router.depositVault(
            _collection2,
            _tokenId2,
            _amount2,
            vault2,
            user2
        );

        assertEq(amountMinted2, magicSwapV2Router.nftAmountToERC20(_amount2));

        _checkNftBalances(_collection2, _tokenId2, _amount2, address(vault2));
        _checkERC20Balances(_collection2, _tokenId2, _amount2, address(vault2), user2, 0);

        // withdraw 1
        vm.startPrank(user1);
        IERC20(address(vault1)).approve(address(magicSwapV2Router), magicSwapV2Router.nftAmountToERC20(_amount1));

        uint256 amountBurned1 = magicSwapV2Router.withdrawVault(
            _collection1,
            _tokenId1,
            _amount1,
            vault1,
            user3
        );
        vm.stopPrank();

        assertEq(amountBurned1, amountMinted1);
        assertEq(IERC20(address(vault1)).balanceOf(user1), 0);
        assertEq(IERC20(address(vault1)).balanceOf(address(vault1)), 0);

        _checkNftBalances(_collection1, _tokenId1, _amount1, user3);

        // withdraw 2
        vm.startPrank(user2);
        IERC20(address(vault2)).approve(address(magicSwapV2Router), magicSwapV2Router.nftAmountToERC20(_amount2));

        uint256 amountBurned2 = magicSwapV2Router.withdrawVault(
            _collection2,
            _tokenId2,
            _amount2,
            vault2,
            user4
        );
        vm.stopPrank();
        assertEq(amountBurned2, amountMinted2);
        assertEq(IERC20(address(vault2)).balanceOf(user2), 0);
        assertEq(IERC20(address(vault2)).balanceOf(address(vault2)), 0);

        _checkNftBalances(_collection2, _tokenId2, _amount2, user4);
    }

    function testAddLiquidityNFT(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_tokenId < type(uint256).max - 100);
        vm.assume(_amount > 0);
        // UniswapV2Pair balance is using uint112
        // and amount of NFTs is multiplied by 1e18 when transformed to ERC20
        // and we are depositing multple NFTs
        // so trying to avoid overflow revert
        vm.assume(_amount < type(uint112).max / ONE / 10);

        // user1 liquidity deposit
        collectionArray = [address(nft1), address(nft1), address(nft2), address(nft2)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        amountArray = [uint256(1), 1, _amount++, _amount++];

        (
            address[] memory _collection1,
            uint256[] memory _tokenId1,
            uint256[] memory _amount1
        ) = _mintTokens(user1);

        uint256 amountBDesired1 = 10e18;
        uint256 amountBMin1 = 9.5e18;

        _dealWeth(user1, amountBDesired1);

        vm.prank(user1);
        (uint256 amountA1, uint256 amountB1, uint256 lpAmount1) = magicSwapV2Router.addLiquidityNFT(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            address(weth),
            amountBDesired1,
            amountBMin1,
            user1,
            block.timestamp
        );

        assertEq(amountA1, magicSwapV2Router.nftAmountToERC20(_amount1));
        assertEq(amountB1, amountBDesired1);

        address pair = UniswapV2Library.pairFor(address(factory), address(vault2), address(weth));
        assertEq(weth.balanceOf(pair), amountB1);

        _checkNftBalances(_collection1, _tokenId1, _amount1, address(vault2));
        _checkERC20Balances(_collection1, _tokenId1, _amount1, address(vault2), pair, 0);

        assertEq(IERC20(pair).balanceOf(user1), lpAmount1);

        // user2 liquidity deposit
        collectionArray = [address(nft1), address(nft2), address(nft2), address(nft2)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        // I know, but it's easier to follow values this way
        amountArray = amountArray;

        (
            address[] memory _collection2,
            uint256[] memory _tokenId2,
            uint256[] memory _amount2
        ) = _mintTokens(user2);

        uint256 amountBDesired2 = 10.1e18;
        uint256 amountBMin2 = amountBDesired2;

        _dealWeth(user2, amountBDesired2);

        vm.prank(user2);
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_B_AMOUNT");
        magicSwapV2Router.addLiquidityNFT(
            _collection2,
            _tokenId2,
            _amount2,
            vault2,
            address(weth),
            amountBDesired2,
            amountBMin2,
            user2,
            block.timestamp
        );

        uint256 prevBalance = IERC20(address(vault2)).balanceOf(pair);

        amountBMin2 = 10e18;

        vm.prank(user2);
        (uint256 amountA2, uint256 amountB2, uint256 lpAmount2) = magicSwapV2Router.addLiquidityNFT(
            _collection2,
            _tokenId2,
            _amount2,
            vault2,
            address(weth),
            amountBDesired2,
            amountBMin2,
            user2,
            block.timestamp
        );

        assertEq(amountA2, magicSwapV2Router.nftAmountToERC20(_amount2));
        assertEq(amountB2, amountBMin2);

        assertEq(weth.balanceOf(pair), amountB1 + amountBMin2);

        _checkNftBalances(_collection2, _tokenId2, _amount2, address(vault2));
        _checkERC20Balances(_collection2, _tokenId2, _amount2, address(vault2), pair, prevBalance);

        assertEq(IERC20(pair).balanceOf(user2), lpAmount2);
    }

    function testAddLiquidityNFTETH(uint256 _tokenId, uint256 _amount) public {
        console2.logBytes32(keccak256(type(UniswapV2Pair).creationCode));
        vm.assume(_tokenId < type(uint256).max - 100);
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint112).max / ONE / 10);

        // user1 liquidity deposit
        collectionArray = [address(nft1), address(nft1), address(nft2), address(nft2)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        amountArray = [uint256(1), 1, _amount++, _amount++];

        (
            address[] memory _collection1,
            uint256[] memory _tokenId1,
            uint256[] memory _amount1
        ) = _mintTokens(user1);

        uint256 amountBDesired1 = 10e18;
        uint256 amountBMin1 = 9.5e18;

        vm.deal(user1, amountBDesired1);

        vm.prank(user1);
        (uint256 amountA1, uint256 amountB1, uint256 lpAmount1) = magicSwapV2Router.addLiquidityNFTETH{value: amountBDesired1}(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            amountBMin1,
            user1,
            block.timestamp
        );

        assertEq(amountA1, magicSwapV2Router.nftAmountToERC20(_amount1));
        assertEq(amountB1, amountBDesired1);

        address pair = UniswapV2Library.pairFor(address(factory), address(vault2), address(weth));
        assertEq(weth.balanceOf(pair), amountB1);

        _checkNftBalances(_collection1, _tokenId1, _amount1, address(vault2));
        _checkERC20Balances(_collection1, _tokenId1, _amount1, address(vault2), pair, 0);

        assertEq(IERC20(pair).balanceOf(user1), lpAmount1);

        // user2 liquidity deposit
        collectionArray = [address(nft1), address(nft2), address(nft2), address(nft2)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        // I know, but it's easier to follow values this way
        amountArray = amountArray;

        (
            address[] memory _collection2,
            uint256[] memory _tokenId2,
            uint256[] memory _amount2
        ) = _mintTokens(user2);

        uint256 amountBDesired2 = 10.1e18;
        uint256 amountBMin2 = amountBDesired2;

        vm.deal(user2, amountBDesired2);

        vm.prank(user2);
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_B_AMOUNT");
        magicSwapV2Router.addLiquidityNFTETH{value: amountBDesired2}(
            _collection2,
            _tokenId2,
            _amount2,
            vault2,
            amountBMin2,
            user2,
            block.timestamp
        );

        uint256 prevBalance = IERC20(address(vault2)).balanceOf(pair);

        amountBMin2 = 10e18;

        vm.prank(user2);
        (uint256 amountA2, uint256 amountB2, uint256 lpAmount2) = magicSwapV2Router.addLiquidityNFTETH{value: amountBDesired2}(
            _collection2, _tokenId2, _amount2, vault2, amountBMin2, user2, block.timestamp
        );

        assertEq(amountA2, magicSwapV2Router.nftAmountToERC20(_amount2));
        assertEq(amountB2, amountBMin2);

        assertEq(weth.balanceOf(pair), amountB1 + amountBMin2);

        _checkNftBalances(_collection2, _tokenId2, _amount2, address(vault2));
        _checkERC20Balances(_collection2, _tokenId2, _amount2, address(vault2), pair, prevBalance);

        assertEq(IERC20(pair).balanceOf(user2), lpAmount2);
        assertEq(address(magicSwapV2Router).balance, 0);
    }

    function testRemoveLiquidityNFT(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_tokenId < type(uint256).max - 100);
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint112).max / ONE / 10);

        // user1 liquidity deposit
        collectionArray = [address(nft1), address(nft1), address(nft2), address(nft2)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        amountArray = [uint256(1), 1, _amount++, _amount++];

        (
            address[] memory _collection1,
            uint256[] memory _tokenId1,
            uint256[] memory _amount1
        ) = _mintTokens(user1);

        uint256 amountBDesired1 = 10e18;
        uint256 amountBMin1 = 9.5e18;

        _dealWeth(user1, amountBDesired1);

        vm.prank(user1);
        (uint256 amountA1, uint256 amountB1, uint256 lpAmount1) = magicSwapV2Router.addLiquidityNFT(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            address(weth),
            amountBDesired1,
            amountBMin1,
            user1,
            block.timestamp
        );

        {
            // user 2 liquidity deposit
            collectionArray = [address(nft1), address(nft2), address(nft2), address(nft2)];
            tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
            // I know, but it's easier to follow values this way
            amountArray = amountArray;

            (
                address[] memory _collection2,
                uint256[] memory _tokenId2,
                uint256[] memory _amount2
            ) = _mintTokens(user2);

            uint256 amountBDesired2 = 10.1e18;
            uint256 amountBMin2 = 10e18;

            _dealWeth(user2, amountBDesired2);

            vm.prank(user2);
            magicSwapV2Router.addLiquidityNFT(
                _collection2,
                _tokenId2,
                _amount2,
                vault2,
                address(weth),
                amountBDesired2,
                amountBMin2,
                user2,
                block.timestamp
            );
        }

        address pair = UniswapV2Library.pairFor(address(factory), address(vault2), address(weth));

        vm.prank(user1);
        IERC20(pair).approve(address(magicSwapV2Router), lpAmount1);

        vm.prank(user1);
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        magicSwapV2Router.removeLiquidityNFT(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            address(weth),
            lpAmount1,
            amountA1,
            amountB1,
            user1,
            block.timestamp,
            true
        );

        vm.prank(user1);
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_B_AMOUNT");
        magicSwapV2Router.removeLiquidityNFT(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            address(weth),
            lpAmount1,
            0,
            amountB1,
            user1,
            block.timestamp,
            true
        );

        vm.prank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        magicSwapV2Router.removeLiquidityNFT(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            address(weth),
            lpAmount1,
            0,
            0,
            user1,
            block.timestamp,
            true
        );

        _amount1[3] -= 1;
        amountA1 -= 1e18;
        amountB1 -= 1e6;

        uint256 prevWETHBalance = weth.balanceOf(user1);

        vm.prank(user1);
        (uint256 amountA3, uint256 amountB3) = magicSwapV2Router.removeLiquidityNFT(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            address(weth),
            lpAmount1,
            amountA1,
            amountB1,
            user1,
            block.timestamp,
            true
        );

        assertEq(amountA3, 0);
        assertEq(amountB3, weth.balanceOf(user1) - prevWETHBalance);

        _checkNftBalances(_collection1, _tokenId1, _amount1, user1);

        assertEq(IERC20(pair).balanceOf(user1), 0);
        assertEq(IERC20(address(vault2)).balanceOf(user1), 0);
        assertEq(IERC20(pair).balanceOf(address(magicSwapV2Router)), 0);
        assertEq(IERC20(address(vault2)).balanceOf(address(magicSwapV2Router)), 0);
        assertEq(address(magicSwapV2Router).balance, 0);
    }

    function testRemoveLiquidityNFTETH(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_tokenId < type(uint256).max - 100);
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint112).max / ONE / 10);

        // user1 liquidity deposit
        collectionArray = [address(nft1), address(nft1), address(nft2), address(nft2)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        amountArray = [uint256(1), 1, _amount++, _amount++];

        (
            address[] memory _collection1,
            uint256[] memory _tokenId1,
            uint256[] memory _amount1
        ) = _mintTokens(user1);

        uint256 amountBDesired1 = 10e18;
        uint256 amountBMin1 = 9.5e18;

        _dealWeth(user1, amountBDesired1);

        vm.prank(user1);
        (uint256 amountA1, uint256 amountB1, uint256 lpAmount1) = magicSwapV2Router.addLiquidityNFT(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            address(weth),
            amountBDesired1,
            amountBMin1,
            user1,
            block.timestamp
        );

        {
            // user 2 liquidity deposit
            collectionArray = [address(nft1), address(nft2), address(nft2), address(nft2)];
            tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
            // I know, but it's easier to follow values this way
            amountArray = amountArray;

            (
                address[] memory _collection2,
                uint256[] memory _tokenId2,
                uint256[] memory _amount2
            ) = _mintTokens(user2);

            uint256 amountBDesired2 = 10.1e18;
            uint256 amountBMin2 = 10e18;

            _dealWeth(user2, amountBDesired2);

            vm.prank(user2);
            magicSwapV2Router.addLiquidityNFT(
                _collection2,
                _tokenId2,
                _amount2,
                vault2,
                address(weth),
                amountBDesired2,
                amountBMin2,
                user2,
                block.timestamp
            );
        }

        address pair = UniswapV2Library.pairFor(address(factory), address(vault2), address(weth));

        vm.prank(user1);
        IERC20(pair).approve(address(magicSwapV2Router), lpAmount1);

        vm.prank(user1);
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        magicSwapV2Router.removeLiquidityNFTETH(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            lpAmount1,
            amountA1,
            amountB1,
            user1,
            block.timestamp,
            true
        );

        vm.prank(user1);
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_B_AMOUNT");
        magicSwapV2Router.removeLiquidityNFTETH(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            lpAmount1,
            0,
            amountB1,
            user1,
            block.timestamp,
            true
        );

        vm.prank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        magicSwapV2Router.removeLiquidityNFTETH(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            lpAmount1,
            0,
            0,
            user1,
            block.timestamp,
            true
        );

        _amount1[3] -= 1;
        amountA1 -= 1e18;
        amountB1 -= 1e6;

        uint256 prevETHBalance = user1.balance;

        vm.prank(user1);
        (uint256 amountA3, uint256 amountB3) = magicSwapV2Router.removeLiquidityNFTETH(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            lpAmount1,
            amountA1,
            amountB1,
            user1,
            block.timestamp,
            true
        );

        assertEq(amountA3, 0);
        assertEq(amountB3, user1.balance - prevETHBalance);

        _checkNftBalances(_collection1, _tokenId1, _amount1, user1);

        assertEq(weth.balanceOf(user1), 0);
        assertEq(IERC20(pair).balanceOf(user1), 0);
        assertEq(IERC20(address(vault2)).balanceOf(user1), 0);
        assertEq(IERC20(pair).balanceOf(address(magicSwapV2Router)), 0);
        assertEq(IERC20(address(vault2)).balanceOf(address(magicSwapV2Router)), 0);
        assertEq(address(magicSwapV2Router).balance, 0);
    }

    function _seedLiquidity1(uint256 _tokenId) public returns (uint256 tokenId) {
        collectionArray = [
            address(nft1), address(nft1), address(nft1), address(nft1),
            address(nft1), address(nft1), address(nft1), address(nft1)
        ];
        collectionArray1 = collectionArray;

        tokenIdArray = [
            _tokenId++, _tokenId++, _tokenId++, _tokenId++,
            _tokenId++, _tokenId++, _tokenId++, _tokenId++
        ];
        tokenIdArray1 = tokenIdArray;

        amountArray = [
            uint256(1), 1, 1, 1,
            uint256(1), 1, 1, 1
        ];
        amountArray1 = amountArray;

        (
            address[] memory _collection1,
            uint256[] memory _tokenId1,
            uint256[] memory _amount1
        ) = _mintTokens(user1);

        uint256 amountBDesired1 = 1000e18 / 2;
        uint256 amountBMin1 = 9500e18 / 2;

        _dealWeth(user1, amountBDesired1);

        vm.prank(user1);
        magicSwapV2Router.addLiquidityNFT(
            _collection1,
            _tokenId1,
            _amount1,
            vault1,
            address(weth),
            amountBDesired1,
            amountBMin1,
            user1,
            block.timestamp
        );

        return _tokenId;
    }

    function _seedLiquidity2(uint256 _tokenId, uint256 _amount) public returns (uint256 tokenId, uint256 amount) {
        collectionArray = [
            address(nft1), address(nft1), address(nft1), address(nft1),
            address(nft2), address(nft2), address(nft2), address(nft2)
        ];
        tokenIdArray = [
            _tokenId++, _tokenId++, _tokenId++, _tokenId++,
            _tokenId++, _tokenId++, _tokenId++, _tokenId++
        ];
        amountArray = [
            uint256(1), 1, 1, 1,
            _amount++, _amount++, _amount++, _amount++
        ];

        (
            address[] memory _collection1,
            uint256[] memory _tokenId1,
            uint256[] memory _amount1
        ) = _mintTokens(user1);

        uint256 amountBDesired1 = 1000e18;
        uint256 amountBMin1 = 9500e18;

        _dealWeth(user1, amountBDesired1);

        vm.prank(user1);
        magicSwapV2Router.addLiquidityNFT(
            _collection1,
            _tokenId1,
            _amount1,
            vault2,
            address(weth),
            amountBDesired1,
            amountBMin1,
            user1,
            block.timestamp
        );

        return (_tokenId, _amount);
    }

    function testSwapNftForTokens(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_tokenId < type(uint256).max - 100);
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint112).max / ONE / 10);

        (_tokenId, _amount) = _seedLiquidity2(_tokenId, _amount);

        collectionArray = [address(nft1), address(nft1), address(nft2), address(nft2)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        amountArray = [uint256(1), 1, _amount, _amount];

        (
            address[] memory _collection1,
            uint256[] memory _tokenId1,
            uint256[] memory _amount1
        ) = _mintTokens(user2);

        address[] memory path = new address[](2);
        path[0] = address(vault2);
        path[1] = address(weth);

        (uint256 reserveVault, uint256 reserveWeth) = UniswapV2Library.getReserves(address(factory), address(vault2), address(weth));
        address pair = UniswapV2Library.pairFor(address(factory), address(vault2), address(weth));
        uint256 amountIn = magicSwapV2Router.nftAmountToERC20(_amount1);
        uint256 amountOut = UniswapV2Library.getAmountOut(amountIn, reserveVault, reserveWeth, pair, address(factory));
        uint256 amountOutMin = amountOut;

        vm.prank(user2);
        uint256[] memory amounts = magicSwapV2Router.swapNftForTokens(
            _collection1,
            _tokenId1,
            _amount1,
            amountOutMin,
            path,
            user2,
            block.timestamp
        );

        _checkNftBalances(_collection1, _tokenId1, _amount1, address(vault2));
        assertEq(amounts[0], amountIn);
        assertEq(amounts[1], amountOut);

        assertEq(weth.balanceOf(user2), amountOut);
        assertEq(weth.balanceOf(address(magicSwapV2Router)), 0);
        assertEq(IERC20(address(vault2)).balanceOf(user2), 0);
        assertEq(IERC20(address(vault2)).balanceOf(address(magicSwapV2Router)), 0);
        assertEq(user2.balance, 0);
        assertEq(address(magicSwapV2Router).balance, 0);
    }

    function testSwapNftForETH(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_tokenId < type(uint256).max - 100);
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint112).max / ONE / 10);

        (_tokenId, _amount) = _seedLiquidity2(_tokenId, _amount);

        collectionArray = [address(nft1), address(nft1), address(nft2), address(nft2)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++, _tokenId++];
        amountArray = [uint256(1), 1, _amount, _amount];

        (
            address[] memory _collection1,
            uint256[] memory _tokenId1,
            uint256[] memory _amount1
        ) = _mintTokens(user2);

        address[] memory path = new address[](2);
        path[0] = address(vault2);
        path[1] = address(weth);

        address[] memory wrongPath = new address[](2);
        wrongPath[0] = address(vault2);
        wrongPath[1] = address(vault1);

        (uint256 reserveVault, uint256 reserveWeth) = UniswapV2Library.getReserves(address(factory), address(vault2), address(weth));
        address pair = UniswapV2Library.pairFor(address(factory), address(vault2), address(weth));
        uint256 amountIn = magicSwapV2Router.nftAmountToERC20(_amount1);
        uint256 amountOut = UniswapV2Library.getAmountOut(amountIn, reserveVault, reserveWeth, pair, address(factory));
        uint256 amountOutMin = amountOut;

        uint256 prevETHBalance = user2.balance;

        vm.prank(user2);
        vm.expectRevert("MagicswapV2Router: INVALID_PATH");
        magicSwapV2Router.swapNftForETH(
            _collection1,
            _tokenId1,
            _amount1,
            amountOutMin,
            wrongPath,
            user2,
            block.timestamp
        );

        vm.prank(user2);
        uint256[] memory amounts = magicSwapV2Router.swapNftForETH(
            _collection1,
            _tokenId1,
            _amount1,
            amountOutMin,
            path,
            user2,
            block.timestamp
        );

        _checkNftBalances(_collection1, _tokenId1, _amount1, address(vault2));
        assertEq(amounts[0], amountIn);
        assertEq(amounts[1], amountOut);

        assertEq(weth.balanceOf(user2), 0);
        assertEq(weth.balanceOf(address(magicSwapV2Router)), 0);
        assertEq(IERC20(address(vault2)).balanceOf(user2), 0);
        assertEq(IERC20(address(vault2)).balanceOf(address(magicSwapV2Router)), 0);
        assertEq(user2.balance, prevETHBalance + amountOut);
        assertEq(address(magicSwapV2Router).balance, 0);
    }

    function testSwapTokensForNft(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_tokenId < type(uint256).max - 100);
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint112).max / ONE / 10);

        (_tokenId, _amount) = _seedLiquidity2(_tokenId, _amount);

        collectionArray = [collectionArray[0], collectionArray[3], collectionArray[4]];
        tokenIdArray = [tokenIdArray[0], tokenIdArray[3], tokenIdArray[4]];
        amountArray = [amountArray[0], amountArray[3], amountArray[4]];

        address[] memory _collection1 = collectionArray;
        uint256[] memory _tokenId1 = tokenIdArray;
        uint256[] memory _amount1 = amountArray;

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(vault2);

        (uint256 reserveVault, uint256 reserveWeth) = UniswapV2Library.getReserves(address(factory), address(vault2), address(weth));
        address pair = UniswapV2Library.pairFor(address(factory), address(vault2), address(weth));
        uint256 amountOut = magicSwapV2Router.nftAmountToERC20(_amount1);
        uint256 amountIn = UniswapV2Library.getAmountIn(amountOut, reserveWeth, reserveVault, pair, address(factory));
        uint256 amountInMax = amountIn;

        _dealWeth(user2, amountIn);
        uint256 prevETHBalance = user2.balance;

        vm.prank(user2);
        uint256[] memory amounts = magicSwapV2Router.swapTokensForNft(
            _collection1,
            _tokenId1,
            _amount1,
            amountInMax,
            path,
            user2,
            block.timestamp
        );

        _checkNftBalances(_collection1, _tokenId1, _amount1, user2);
        assertEq(amounts[0], amountIn);
        assertEq(amounts[1], amountOut);

        assertEq(weth.balanceOf(user2), 0);
        assertEq(weth.balanceOf(address(magicSwapV2Router)), 0);
        assertEq(IERC20(address(vault2)).balanceOf(user2), 0);
        assertEq(IERC20(address(vault2)).balanceOf(address(magicSwapV2Router)), 0);
        assertEq(user2.balance, prevETHBalance);
        assertEq(address(magicSwapV2Router).balance, 0);
    }

    function testSwapETHForNft(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_tokenId < type(uint256).max - 100);
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint112).max / ONE / 10);

        (_tokenId, _amount) = _seedLiquidity2(_tokenId, _amount);

        collectionArray = [collectionArray[0], collectionArray[3], collectionArray[4]];
        tokenIdArray = [tokenIdArray[0], tokenIdArray[3], tokenIdArray[4]];
        amountArray = [amountArray[0], amountArray[3], amountArray[4]];

        address[] memory _collection1 = collectionArray;
        uint256[] memory _tokenId1 = tokenIdArray;
        uint256[] memory _amount1 = amountArray;

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(vault2);

        (uint256 reserveVault, uint256 reserveWeth) = UniswapV2Library.getReserves(address(factory), address(vault2), address(weth));
        address pair = UniswapV2Library.pairFor(address(factory), address(vault2), address(weth));
        uint256 amountOut = magicSwapV2Router.nftAmountToERC20(_amount1);
        uint256 amountIn = UniswapV2Library.getAmountIn(amountOut, reserveWeth, reserveVault, pair, address(factory));

        uint256 dust = 1e18;
        vm.deal(user2, amountIn + dust);
        uint256 prevETHBalance = user2.balance;

        vm.prank(user2);
        uint256[] memory amounts = magicSwapV2Router.swapETHForNft{value: amountIn + dust}(
            _collection1,
            _tokenId1,
            _amount1,
            path,
            user2,
            block.timestamp
        );

        _checkNftBalances(_collection1, _tokenId1, _amount1, user2);
        assertEq(amounts[0], amountIn);
        assertEq(amounts[1], amountOut);

        assertEq(weth.balanceOf(user2), 0);
        assertEq(weth.balanceOf(address(magicSwapV2Router)), 0);
        assertEq(IERC20(address(vault2)).balanceOf(user2), 0);
        assertEq(IERC20(address(vault2)).balanceOf(address(magicSwapV2Router)), 0);
        assertEq(user2.balance, prevETHBalance - amountIn);
        assertEq(address(magicSwapV2Router).balance, 0);
    }

    function testSwapNftForNft(uint256 _tokenId, uint256 _amount) public {
        vm.assume(_tokenId < type(uint256).max - 100);
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint112).max / ONE / 10);

        _tokenId = _seedLiquidity1(_tokenId);
        (_tokenId, _amount) = _seedLiquidity2(_tokenId, _amount);

        collectionArray = [collectionArray[7]];
        tokenIdArray = [tokenIdArray[7]];
        amountArray = [amountArray[7]];

        address[] memory _collectionOut = collectionArray;
        uint256[] memory _tokenIdOut = tokenIdArray;
        uint256[] memory _amountOut = amountArray;

        collectionArray = [address(nft1), address(nft1), address(nft1)];
        tokenIdArray = [_tokenId++, _tokenId++, _tokenId++];
        amountArray = [uint256(1), 1, 1];

        (
            address[] memory _collectionIn,
            uint256[] memory _tokenIdIn,
            uint256[] memory _amountIn
        ) = _mintTokens(user2);

        address[] memory path = new address[](3);
        path[0] = address(vault1);
        path[1] = address(weth);
        path[2] = address(vault2);

        uint256 amountIn;
        uint256 amountOut;
        {
            amountIn = magicSwapV2Router.nftAmountToERC20(_amountIn);
            uint256[] memory amounts = UniswapV2Library.getAmountsOut(address(factory), amountIn, path);
            amountOut = amounts[amounts.length - 1];
            console2.log("amountOut", amountOut);
        }

        _amountOut[0] = amountOut / ONE;

        assertTrue(magicSwapV2Router.nftAmountToERC20(_amountOut) < amountOut);
        assertEq(magicSwapV2Router.nftAmountToERC20(_amountOut) / ONE, amountOut / ONE);

        uint256 prevPairVault2Balance;
        {
            address pair = UniswapV2Library.pairFor(address(factory), path[1], path[2]);
            prevPairVault2Balance = IERC20(address(vault2)).balanceOf(pair);
        }

        vm.prank(user2);
        uint256[] memory swapAmounts = magicSwapV2Router.swapNftForNft(
            _collectionIn,
            _tokenIdIn,
            _amountIn,
            _collectionOut,
            _tokenIdOut,
            _amountOut,
            path,
            user2,
            block.timestamp
        );

        _checkNftBalances(_collectionIn, _tokenIdIn, _amountIn, address(vault1));
        _checkNftBalances(_collectionOut, _tokenIdOut, _amountOut, user2);
        assertEq(swapAmounts[0], amountIn);
        assertEq(swapAmounts[2], amountOut);

        uint256 dust = swapAmounts[swapAmounts.length - 1] - amountOut / ONE * ONE;
        console2.log("dust", dust);
        assertTrue(dust > 0);
        assertEq(
            IERC20(address(vault2)).balanceOf(
                UniswapV2Library.pairFor(address(factory), path[1], path[2])
            ),
            prevPairVault2Balance - amountOut + dust
        );

        assertEq(weth.balanceOf(user2), 0);
        assertEq(weth.balanceOf(address(magicSwapV2Router)), 0);

        assertEq(IERC20(address(vault1)).balanceOf(user2), 0);
        assertEq(IERC20(address(vault1)).balanceOf(address(magicSwapV2Router)), 0);
        assertEq(IERC20(address(vault2)).balanceOf(user2), 0);
        assertEq(IERC20(address(vault2)).balanceOf(address(magicSwapV2Router)), 0);

        assertEq(address(magicSwapV2Router).balance, 0);
    }
}
