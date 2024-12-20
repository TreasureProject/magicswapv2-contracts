// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../StakingContractMainnet.sol";
import "./mock/Token.sol";

contract TestSetup is Test {
    address johnDoe = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address janeDoe = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address zeroAddress = 0x0000000000000000000000000000000000000000;

    uint256 MAX_UINT256 = type(uint256).max;
    uint112 MAX_UINT112 = type(uint112).max;
    uint32 testIncentiveDuration = 2592000;
    uint112 testIncentiveAmount = 1e21;

    bytes4 invalidTimeFrame = bytes4(keccak256("InvalidTimeFrame()"));
    bytes4 notSubscribed = bytes4(keccak256("NotSubscribed()"));
    bytes4 alreadySubscribed = bytes4(keccak256("AlreadySubscribed()"));
    bytes4 noToken = bytes4(keccak256("NoToken()"));
    bytes4 invalidInput = bytes4(keccak256("InvalidInput()"));
    bytes4 insufficientStakedAmount = bytes4(keccak256("InsufficientStakedAmount"));
    bytes4 notStaked = bytes4(keccak256("NotStaked()"));
    bytes4 invalidIndex = bytes4(keccak256("InvalidIndex()"));
    bytes4 panic = 0x4e487b71;
    bytes overflow = abi.encodePacked(panic, bytes32(uint256(0x11)));

    StakingContractMainnet stakingContract;

    Token tokenA;
    Token tokenB;
    Token tokenC;

    uint256 pastIncentive;
    uint256 ongoingIncentive;
    uint256 futureIncentive;

    function setUp() public {
        stakingContract = new StakingContractMainnet();
        tokenA = new Token();
        tokenB = new Token();
        tokenC = new Token();

        tokenA.mint(MAX_UINT256);
        tokenB.mint(MAX_UINT256);
        tokenC.mint(MAX_UINT256);

        tokenA.approve(address(stakingContract), MAX_UINT256);
        tokenB.approve(address(stakingContract), MAX_UINT256);
        tokenC.approve(address(stakingContract), MAX_UINT256);

        tokenA.transfer(johnDoe, MAX_UINT112);
        tokenA.transfer(janeDoe, MAX_UINT112);

        vm.prank(johnDoe);
        tokenA.approve(address(stakingContract), MAX_UINT256);

        vm.prank(janeDoe);
        tokenA.approve(address(stakingContract), MAX_UINT256);

        uint112 amount = testIncentiveAmount;
        uint256 currentTime = testIncentiveDuration * 30;
        uint256 duration = testIncentiveDuration;

        vm.warp(currentTime - duration);
        pastIncentive = _createIncentive(
            address(tokenA), address(tokenB), amount, uint32(block.timestamp), uint32(block.timestamp + duration)
        );
        vm.warp(currentTime);
        ongoingIncentive = _createIncentive(
            address(tokenA), address(tokenB), amount, uint32(block.timestamp), uint32(block.timestamp + duration)
        );
        futureIncentive = _createIncentive(
            address(tokenA),
            address(tokenB),
            amount,
            uint32(block.timestamp + duration),
            uint32(block.timestamp + duration * 2)
        );
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }

    function _createIncentive(address token, address rewardToken, uint112 amount, uint32 startTime, uint32 endTime)
        public
        returns (uint256)
    {
        uint256 count = stakingContract.incentiveCount();
        uint256 thisBalance = Token(rewardToken).balanceOf(address(this));
        uint256 stakingContractBalance = Token(rewardToken).balanceOf(address(stakingContract));

        if (amount <= 0) {
            vm.expectRevert(invalidInput);
            return stakingContract.createIncentive(token, rewardToken, amount, startTime, endTime);
        }

        if (endTime <= startTime || endTime <= block.timestamp) {
            vm.expectRevert(invalidTimeFrame);
            return stakingContract.createIncentive(token, rewardToken, amount, startTime, endTime);
        }

        uint256 id = stakingContract.createIncentive(token, rewardToken, amount, startTime, endTime);

        StakingContractMainnet.Incentive memory incentive = _getIncentive(id);

        assertEq(incentive.creator, address(this));
        assertEq(incentive.token, token);
        assertEq(incentive.rewardToken, rewardToken);
        assertEq(incentive.lastRewardTime, startTime < block.timestamp ? uint32(block.timestamp) : startTime);
        assertEq(incentive.endTime, endTime);
        assertEq(incentive.rewardRemaining, amount);
        assertEq(incentive.liquidityStaked, 0);
        assertEq(incentive.rewardPerLiquidity, type(uint256).max / 2);
        assertEq(count + 1, id);
        assertEq(stakingContract.incentiveCount(), id);
        assertEq(thisBalance - amount, Token(rewardToken).balanceOf(address(this)));
        assertEq(stakingContractBalance + amount, Token(rewardToken).balanceOf(address(stakingContract)));
        return id;
    }

    function _updateIncentive(uint256 incentiveId, int112 changeAmount, uint32 startTime, uint32 endTime) public {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        Token(incentive.rewardToken).balanceOf(address(this));
        Token(incentive.rewardToken).balanceOf(address(stakingContract));
        uint32 newStartTime = startTime == 0
            ? incentive.lastRewardTime
            : (startTime < uint32(block.timestamp) ? uint32(block.timestamp) : startTime);
        uint32 newEndTime =
            endTime == 0 ? incentive.endTime : (endTime < uint32(block.timestamp) ? uint32(block.timestamp) : endTime);

        if (newStartTime >= newEndTime) {
            vm.expectRevert(invalidTimeFrame);
            stakingContract.updateIncentive(incentiveId, changeAmount, startTime, endTime);
            return;
        }

        if (changeAmount == type(int112).min) {
            vm.expectRevert(overflow);
            stakingContract.updateIncentive(incentiveId, changeAmount, startTime, endTime);
            return;
        }

        if (changeAmount > 0 && uint112(changeAmount) + uint256(incentive.rewardRemaining) > type(uint112).max) {
            vm.expectRevert(overflow);
            stakingContract.updateIncentive(incentiveId, changeAmount, startTime, endTime);
            return;
        }

        stakingContract.updateIncentive(incentiveId, changeAmount, startTime, endTime);

        if (changeAmount < 0 && uint112(-changeAmount) > incentive.rewardRemaining) {
            changeAmount = -int112(incentive.rewardRemaining);
        }

        StakingContractMainnet.Incentive memory updatedIncentive = _getIncentive(incentiveId);
        assertEq(updatedIncentive.lastRewardTime, newStartTime);
        assertEq(updatedIncentive.endTime, newEndTime);
        assertEq(
            updatedIncentive.rewardRemaining,
            changeAmount < 0
                ? incentive.rewardRemaining - uint112(-changeAmount)
                : incentive.rewardRemaining + uint112(changeAmount)
        );
        assertEq(updatedIncentive.creator, incentive.creator);
        assertEq(updatedIncentive.token, incentive.token);
        assertEq(updatedIncentive.rewardToken, incentive.rewardToken);
        assertEq(updatedIncentive.liquidityStaked, incentive.liquidityStaked);
    }

    function _stake(address token, uint112 amount, address from, bool transferRewards) public {
        // todo check if current incentives stakes got updates correctly
        uint256 userBalanceBefore = Token(token).balanceOf(from);
        uint256 stakingContractBalanceBefore = Token(token).balanceOf(address(stakingContract));
        uint256 userLiquidityBefore = _getUsersLiquidityStaked(from, token);

        if (amount > userBalanceBefore) {
            vm.expectRevert("TRANSFER_FROM_FAILED");
            vm.prank(from);
            stakingContract.stakeToken(token, amount, transferRewards);
            return;
        }

        if (amount > type(uint112).max - userLiquidityBefore) {
            vm.expectRevert(overflow);
            vm.prank(from);
            stakingContract.stakeToken(token, amount, transferRewards);
            return;
        }

        vm.prank(from);
        stakingContract.stakeToken(token, amount, transferRewards);

        uint256 userBalanceAfter = Token(token).balanceOf(from);
        uint256 stakingContractBalanceAfter = Token(token).balanceOf(address(stakingContract));
        uint256 userLiquidityAfter = _getUsersLiquidityStaked(from, token);

        assertEq(userBalanceBefore - amount, userBalanceAfter);
        assertEq(userLiquidityBefore + amount, userLiquidityAfter);
        assertEq(stakingContractBalanceBefore + amount, stakingContractBalanceAfter);
    }

    function _unstake(address token, uint112 amount, address from, bool transferRewards) public {
        uint256 userBalanceBefore = Token(token).balanceOf(from);
        uint256 userLiquidityBefore = _getUsersLiquidityStaked(from, token);

        if (amount > userLiquidityBefore) {
            vm.expectRevert(insufficientStakedAmount);
            vm.prank(from);
            stakingContract.unstakeToken(token, amount, transferRewards);
            return;
        }

        vm.prank(from);
        stakingContract.unstakeToken(token, amount, transferRewards);

        uint256 userBalanceAfter = Token(token).balanceOf(from);
        uint256 userLiquidityAfter = _getUsersLiquidityStaked(from, token);

        assertEq(userBalanceBefore + amount, userBalanceAfter);
        assertEq(userLiquidityBefore - amount, userLiquidityAfter);
    }

    function _subscribeToIncentive(uint256 incentiveId, address from) public {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        uint112 liquidity = _getUsersLiquidityStaked(from, incentive.token);

        (uint256 rpl) = stakingContract.rewardPerLiquidityLast(from, incentiveId);

        if (incentiveId > stakingContract.incentiveCount() || incentiveId <= 0) {
            vm.prank(from);
            vm.expectRevert(invalidInput);
            return stakingContract.subscribeToIncentive(incentiveId);
        }

        if (rpl != 0) {
            vm.prank(from);
            vm.expectRevert(alreadySubscribed);
            return stakingContract.subscribeToIncentive(incentiveId);
        }

        if (liquidity == 0) {
            vm.prank(from);
            vm.expectRevert(notStaked);
            return stakingContract.subscribeToIncentive(incentiveId);
        }

        vm.prank(from);
        stakingContract.subscribeToIncentive(incentiveId);

        StakingContractMainnet.Incentive memory incentiveAfter = _getIncentive(incentiveId);
        uint144 subscribedIncentives = _getUsersSubscribedIncentives(from, incentive.token);

        assertEq(incentive.liquidityStaked + liquidity, incentiveAfter.liquidityStaked);
        assertEq(uint24(subscribedIncentives), uint24(incentiveId));
        assertEq(stakingContract.rewardPerLiquidityLast(from, incentiveId), incentiveAfter.rewardPerLiquidity);
        if (block.timestamp > incentive.lastRewardTime) {
            assertEq(
                incentiveAfter.lastRewardTime,
                block.timestamp > incentiveAfter.endTime ? incentiveAfter.endTime : block.timestamp
            );
        } else {
            assertEq(incentiveAfter.lastRewardTime, incentive.lastRewardTime);
        }
    }

    function _stakeAndSubscribeToIncentives(
        address token,
        uint112 amount,
        uint256[] memory incentiveIds,
        address from,
        bool transferRewards
    ) public {
        uint256 userBalanceBefore = Token(token).balanceOf(from);
        uint256 stakingContractBalanceBefore = Token(token).balanceOf(address(stakingContract));
        uint256 userLiquidityBefore = _getUsersLiquidityStaked(from, token);
        uint144 subscribedIncentivesBefore = _getUsersSubscribedIncentives(from, token);

        if (amount > userBalanceBefore) {
            vm.expectRevert(overflow);
            vm.prank(from);
            stakingContract.stakeAndSubscribeToIncentives(token, amount, incentiveIds, transferRewards);
            return;
        }

        if (amount > type(uint112).max - userLiquidityBefore) {
            vm.expectRevert(overflow);
            vm.prank(from);
            stakingContract.stakeAndSubscribeToIncentives(token, amount, incentiveIds, transferRewards);
            return;
        }

        if (amount == 0) {
            vm.prank(from);
            vm.expectRevert(notStaked);
            stakingContract.stakeAndSubscribeToIncentives(token, amount, incentiveIds, transferRewards);
            return;
        }

        vm.prank(from);
        stakingContract.stakeAndSubscribeToIncentives(token, amount, incentiveIds, transferRewards);

        uint256 userBalanceAfter = Token(token).balanceOf(from);
        uint256 stakingContractBalanceAfter = Token(token).balanceOf(address(stakingContract));
        uint256 userLiquidityAfter = _getUsersLiquidityStaked(from, token);
        uint144 subscribedIncentivesAfter = _getUsersSubscribedIncentives(from, token);

        assertEq(userBalanceBefore - amount, userBalanceAfter);
        assertEq(userLiquidityBefore + amount, userLiquidityAfter);
        assertEq(stakingContractBalanceBefore + amount, stakingContractBalanceAfter);
        assertLt(subscribedIncentivesBefore, subscribedIncentivesAfter);
    }

    function _accrueRewards(uint256 incentiveId) public {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        uint256 rewardPerLiquidity;
        uint256 rewardRemaining;
        uint256 lastRewardTime;
        uint256 maxTime = block.timestamp < incentive.endTime ? block.timestamp : incentive.endTime;
        if (incentive.liquidityStaked > 0 && incentive.lastRewardTime < maxTime) {
            (rewardPerLiquidity, rewardRemaining, lastRewardTime) = _calculateAccrueChange(incentiveId);
        } else {
            rewardPerLiquidity = incentive.rewardPerLiquidity;
            rewardRemaining = incentive.rewardRemaining;
            if (incentive.lastRewardTime < block.timestamp) {
                lastRewardTime = maxTime;
            } else {
                lastRewardTime = incentive.lastRewardTime;
            }
        }

        if (incentiveId > stakingContract.incentiveCount() || incentiveId <= 0) {
            vm.expectRevert(invalidInput);
            stakingContract.accrueRewards(incentiveId);
            return;
        }

        stakingContract.accrueRewards(incentiveId);
        StakingContractMainnet.Incentive memory updatedIncentive = _getIncentive(incentiveId);
        assertEq(updatedIncentive.rewardPerLiquidity, rewardPerLiquidity);
        assertEq(updatedIncentive.lastRewardTime, lastRewardTime);
        assertEq(updatedIncentive.rewardRemaining, rewardRemaining);
    }

    function _calculateAccrueChange(uint256 incentiveId)
        public
        view
        returns (uint256 rewardPerLiquidity, uint256 rewardRemaining, uint256 lastRewardTime)
    {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        uint256 totalTime = incentive.endTime - incentive.lastRewardTime;
        if (totalTime == 0 || incentive.liquidityStaked == 0 || block.timestamp < incentive.lastRewardTime) {
            return (incentive.rewardPerLiquidity, incentive.rewardRemaining, incentive.lastRewardTime);
        }
        uint256 maxTime = block.timestamp < incentive.endTime ? block.timestamp : incentive.endTime;
        uint256 passedTime = maxTime - incentive.lastRewardTime;
        uint256 reward = uint256(passedTime) * incentive.rewardRemaining / totalTime;
        uint256 rplChange = reward * type(uint112).max / incentive.liquidityStaked;
        rewardPerLiquidity = incentive.rewardPerLiquidity + rplChange;
        rewardRemaining = incentive.rewardRemaining - reward;
        lastRewardTime = maxTime;
    }

    function _claimReward(uint256 incentiveId, address from) public returns (uint256 reward) {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        uint256 oldBalance = Token(incentive.rewardToken).balanceOf(from);
        (uint256 rewardPerLiquidityLast, uint256 rewardPerLiquidity, uint256 expectedReward) =
            _calculateReward(incentiveId, from);
        uint256[] memory incentiveIds = new uint256[](1);
        incentiveIds[0] = incentiveId;
        if (rewardPerLiquidityLast == 0) {
            vm.prank(from);
            vm.expectRevert(notSubscribed);
            stakingContract.claimRewards(incentiveIds);
            return 0;
        }
        vm.prank(from);
        uint256[] memory rewards = stakingContract.claimRewards(incentiveIds);
        reward = rewards[0];
        assertEq(reward, expectedReward);
        uint256 newBalance = Token(incentive.rewardToken).balanceOf(from);
        assertEq(newBalance - oldBalance, reward);
        StakingContractMainnet.Incentive memory updatedIncentive = _getIncentive(incentiveId);
        assertEq(updatedIncentive.rewardPerLiquidity, rewardPerLiquidity);
        assertEq(stakingContract.rewardPerLiquidityLast(from, incentiveId), rewardPerLiquidity);
    }

    function _calculateReward(uint256 incentiveId, address from)
        internal
        view
        returns (uint256 rplLast, uint256 newRewardPerLiquidity, uint256 reward)
    {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        (newRewardPerLiquidity,,) = _calculateAccrueChange(incentiveId);
        uint256 usersLiquidity = _getUsersLiquidityStaked(from, incentive.token);
        rplLast = stakingContract.rewardPerLiquidityLast(from, incentiveId);
        if (rplLast != 0) {
            reward = (newRewardPerLiquidity - rplLast) * usersLiquidity / type(uint112).max;
        }
    }

    function _getUsersLiquidityStaked(address user, address token) public view returns (uint112) {
        (uint112 liquidity,) = stakingContract.userStakes(user, token);
        return liquidity;
    }

    function _getUsersSubscribedIncentives(address user, address token) public view returns (uint144) {
        (, uint144 incentiveIds) = stakingContract.userStakes(user, token);
        return incentiveIds;
    }

    function _rewardRate(uint256 incentiveId) public view returns (uint256) {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        if (incentive.endTime != incentive.lastRewardTime) {
            return
                incentive.rewardRemaining * uint256(type(uint112).max) / (incentive.endTime - incentive.lastRewardTime);
        } else {
            return 0;
        }
    }

    function _getIncentive(uint256 id) public view returns (StakingContractMainnet.Incentive memory incentive) {
        (
            address creator,
            address token,
            address rewardToken,
            uint32 endTime,
            uint256 rewardPerLiquidity,
            uint32 lastRewardTime,
            uint112 rewardRemaining,
            uint112 liquidityStaked
        ) = stakingContract.incentives(id);
        incentive = StakingContractMainnet.Incentive(
            creator, token, rewardToken, endTime, rewardPerLiquidity, lastRewardTime, rewardRemaining, liquidityStaked
        );
    }

    function assertEqInexact(uint256 value, uint256 shouldBe, uint256 err) public {
        assertTrue(value <= shouldBe + err);
        assertTrue(value >= shouldBe - err);
    }
}
