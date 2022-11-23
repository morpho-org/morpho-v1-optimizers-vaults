// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyVault is TestSetupVaults {
    using WadRayMath for uint256;

    function testCorrectInitialisationDai() public {
        assertEq(daiSupplyVault.owner(), address(this));
        assertEq(daiSupplyVault.name(), "MorphoAaveDAI");
        assertEq(daiSupplyVault.symbol(), "maDAI");
        assertEq(daiSupplyVault.poolToken(), aDai);
        assertEq(daiSupplyVault.asset(), dai);
        assertEq(daiSupplyVault.decimals(), 18);
    }

    function testCorrectInitialisationUsdc() public {
        assertEq(usdcSupplyVault.owner(), address(this));
        assertEq(usdcSupplyVault.name(), "MorphoAaveUSDC");
        assertEq(usdcSupplyVault.symbol(), "maUSDC");
        assertEq(usdcSupplyVault.poolToken(), aUsdc);
        assertEq(usdcSupplyVault.asset(), usdc);
        assertEq(usdcSupplyVault.decimals(), 18);
    }

    function testShouldDepositAmount() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(aDai);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(dai);

        assertGt(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcDAI balance is zero");
        assertApproxEqAbs(
            balanceInP2P.rayMul(p2pSupplyIndex) + balanceOnPool.rayMul(poolSupplyIndex),
            amount.rayDiv(poolSupplyIndex).rayMul(poolSupplyIndex),
            1e10
        );
    }

    function testShouldWithdrawAllAmount() public {
        uint256 amount = 10_000 ether;

        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(dai);
        uint256 expectedOnPool = amount.rayDiv(poolSupplyIndex);

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.withdrawVault(daiSupplyVault, expectedOnPool.rayMul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        assertApproxEqAbs(
            daiSupplyVault.balanceOf(address(vaultSupplier1)),
            0,
            1e3,
            "mcDAI balance not zero"
        );
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllUsdcAmount() public {
        uint256 amount = 1e9;

        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(usdc);
        uint256 expectedOnPool = amount.rayDiv(poolSupplyIndex);

        vaultSupplier1.depositVault(usdcSupplyVault, amount);
        vaultSupplier1.withdrawVault(usdcSupplyVault, expectedOnPool.rayMul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            address(aUsdc),
            address(usdcSupplyVault)
        );

        assertApproxEqAbs(
            usdcSupplyVault.balanceOf(address(vaultSupplier1)),
            0,
            10,
            "mcUSDT balance not zero"
        );
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllShares() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares); // cannot withdraw amount because of Compound rounding errors

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcDAI balance not zero");
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldNotWithdrawWhenNotDeposited() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        vaultSupplier2.redeemVault(daiSupplyVault, shares);
    }

    function testShouldNotWithdrawOnBehalfIfNotAllowed() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        vaultSupplier1.redeemVault(daiSupplyVault, shares, address(vaultSupplier2));
    }

    function testShouldWithdrawOnBehalfIfAllowed() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vaultSupplier1.approve(address(maDai), address(vaultSupplier2), shares);
        vaultSupplier2.redeemVault(daiSupplyVault, shares, address(vaultSupplier1));
    }

    function testShouldNotMintZeroShare() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        vaultSupplier1.mintVault(daiSupplyVault, 0);
    }

    function testShouldNotWithdrawGreaterAmount() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: withdraw more than max");
        vaultSupplier1.withdrawVault(daiSupplyVault, amount * 2);
    }

    function testShouldNotRedeemMoreShares() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        vaultSupplier1.redeemVault(daiSupplyVault, shares + 1);
    }

    function testShouldClaimRewards() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 20 days);

        uint256 balanceBefore = vaultSupplier1.balanceOf(rewardToken);

        (address[] memory rewardTokens, uint256[] memory claimedAmounts) = daiSupplyVault
        .claimRewards(address(vaultSupplier1));

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], rewardToken);
        assertEq(claimedAmounts.length, 1);

        uint256 balanceAfter = vaultSupplier1.balanceOf(rewardToken);

        assertGt(claimedAmounts[0], 0);
        assertApproxEqAbs(
            ERC20(rewardToken).balanceOf(address(daiSupplyVault)),
            0,
            1e4,
            "non zero rewardToken balance on vault"
        );
        assertEq(balanceAfter, balanceBefore + claimedAmounts[0], "unexpected rewardToken balance");
    }

    function testShouldClaimTwiceRewardsWhenDepositedForSameAmountAndTwiceDuration() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        vaultSupplier2.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        (address[] memory rewardTokens1, uint256[] memory claimedAmounts1) = daiSupplyVault
        .claimRewards(address(vaultSupplier1));

        assertEq(rewardTokens1.length, 1);
        assertEq(rewardTokens1[0], rewardToken);
        assertEq(claimedAmounts1.length, 1);

        (address[] memory rewardTokens2, uint256[] memory claimedAmounts2) = daiSupplyVault
        .claimRewards(address(vaultSupplier2));

        assertEq(rewardTokens2.length, 1);
        assertEq(rewardTokens2[0], rewardToken);
        assertEq(claimedAmounts2.length, 1);

        assertApproxEqAbs(
            expectedTotalRewardsAmount,
            claimedAmounts1[0] + claimedAmounts2[0],
            1e5,
            "unexpected total rewards amount"
        );
        assertLe(claimedAmounts1[0] + claimedAmounts2[0], expectedTotalRewardsAmount);
        assertApproxEqAbs(
            claimedAmounts1[0],
            2 * claimedAmounts2[0],
            1e15,
            "unexpected rewards amount"
        ); // not exact because of rewardTokenounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedAtSameTime() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);
        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        (address[] memory rewardTokens1, uint256[] memory claimedAmounts1) = daiSupplyVault
        .claimRewards(address(vaultSupplier1));

        assertEq(rewardTokens1.length, 1);
        assertEq(rewardTokens1[0], rewardToken);
        assertEq(claimedAmounts1.length, 1);

        (address[] memory rewardTokens2, uint256[] memory claimedAmounts2) = daiSupplyVault
        .claimRewards(address(vaultSupplier2));

        assertEq(rewardTokens2.length, 1);
        assertEq(rewardTokens2[0], rewardToken);
        assertEq(claimedAmounts2.length, 1);

        assertApproxEqAbs(
            expectedTotalRewardsAmount,
            claimedAmounts1[0] + claimedAmounts2[0],
            1e5,
            "unexpected total rewards amount"
        );
        assertGe(expectedTotalRewardsAmount, claimedAmounts1[0] + claimedAmounts2[0]);
        assertApproxEqAbs(
            claimedAmounts1[0],
            claimedAmounts2[0],
            1e15,
            "unexpected rewards amount"
        ); // not exact because of rewardTokenounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration1() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        (address[] memory rewardTokens1, uint256[] memory claimedAmounts1) = daiSupplyVault
        .claimRewards(address(vaultSupplier1));

        assertEq(rewardTokens1.length, 1);
        assertEq(rewardTokens1[0], rewardToken);
        assertEq(claimedAmounts1.length, 1);

        (address[] memory rewardTokens2, uint256[] memory claimedAmounts2) = daiSupplyVault
        .claimRewards(address(vaultSupplier2));

        assertEq(rewardTokens2.length, 1);
        assertEq(rewardTokens2[0], rewardToken);
        assertEq(claimedAmounts2.length, 1);

        assertApproxEqAbs(
            expectedTotalRewardsAmount,
            claimedAmounts1[0] + claimedAmounts2[0],
            1e5,
            "unexpected total rewards amount"
        );
        assertGe(expectedTotalRewardsAmount, claimedAmounts1[0] + claimedAmounts2[0]);
        assertApproxEqAbs(
            claimedAmounts1[0],
            claimedAmounts2[0],
            1e15,
            "unexpected rewards amount"
        ); // not exact because of rewardTokenounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration2() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        uint256 shares3 = vaultSupplier3.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);
        vaultSupplier3.redeemVault(daiSupplyVault, shares3 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        vaultSupplier3.redeemVault(daiSupplyVault, shares3 / 2);

        (address[] memory rewardTokens1, uint256[] memory claimedAmounts1) = daiSupplyVault
        .claimRewards(address(vaultSupplier1));

        assertEq(rewardTokens1.length, 1);
        assertEq(rewardTokens1[0], rewardToken);
        assertEq(claimedAmounts1.length, 1);

        (address[] memory rewardTokens2, uint256[] memory claimedAmounts2) = daiSupplyVault
        .claimRewards(address(vaultSupplier2));

        assertEq(rewardTokens2.length, 1);
        assertEq(rewardTokens2[0], rewardToken);
        assertEq(claimedAmounts2.length, 1);

        (address[] memory rewardTokens3, uint256[] memory claimedAmounts3) = daiSupplyVault
        .claimRewards(address(vaultSupplier3));

        assertEq(rewardTokens3.length, 1);
        assertEq(rewardTokens3[0], rewardToken);
        assertEq(claimedAmounts3.length, 1);

        assertApproxEqAbs(
            expectedTotalRewardsAmount,
            claimedAmounts1[0] + claimedAmounts2[0] + claimedAmounts3[0],
            1e5,
            "unexpected total rewards amount"
        );
        assertGe(
            expectedTotalRewardsAmount,
            claimedAmounts1[0] + claimedAmounts2[0] + claimedAmounts3[0]
        );
        assertApproxEqAbs(
            ERC20(rewardToken).balanceOf(address(daiSupplyVault)),
            0,
            1e15,
            "non zero rewardToken balance on vault"
        );
        assertApproxEqAbs(
            claimedAmounts1[0],
            claimedAmounts2[0],
            1e15,
            "unexpected rewards amount 1-2"
        ); // not exact because of rewardTokenounded interests
        assertApproxEqAbs(
            claimedAmounts2[0],
            claimedAmounts3[0],
            1e15,
            "unexpected rewards amount 2-3"
        ); // not exact because of rewardTokenounded interests
    }

    function testRewardsShouldAccrueWhenDepositingOnBehalf() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        vaultSupplier2.depositVault(daiSupplyVault, amount, address(vaultSupplier1));
        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );

        // Should update the unclaimed amount
        vaultSupplier2.depositVault(daiSupplyVault, amount, address(vaultSupplier1));
        uint256 userReward1_1 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier1),
            rewardToken
        );

        vm.warp(block.timestamp + 10 days);
        uint256 userReward1_2 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier1),
            rewardToken
        );

        uint256 userReward2 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier2),
            rewardToken
        );
        assertEq(userReward2, 0);
        assertGt(userReward1_1, 0);
        assertGt(userReward1_2, 0);
        assertApproxEqAbs(userReward1_1, expectedTotalRewardsAmount, 10000);
        assertApproxEqAbs(userReward1_1 * 3, userReward1_2, userReward1_2 / 1000);
    }

    function testRewardsShouldAccrueWhenMintingOnBehalf() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        vaultSupplier2.mintVault(
            daiSupplyVault,
            daiSupplyVault.previewMint(amount),
            address(vaultSupplier1)
        );
        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );
        morpho.updateIndexes(aDai);

        // Should update the unclaimed amount
        vaultSupplier2.mintVault(
            daiSupplyVault,
            daiSupplyVault.previewMint(amount),
            address(vaultSupplier1)
        );

        uint256 userReward1_1 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier1),
            rewardToken
        );

        vm.warp(block.timestamp + 10 days);
        uint256 userReward1_2 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier1),
            rewardToken
        );

        uint256 userReward2 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier2),
            rewardToken
        );
        assertEq(userReward2, 0);
        assertGt(userReward1_1, 0);
        assertApproxEqAbs(userReward1_1, expectedTotalRewardsAmount, 10000);
        assertApproxEqAbs(userReward1_1 * 3, userReward1_2, userReward1_2 / 1000);
    }

    function testRewardsShouldAccrueWhenRedeemingToReceiver() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );
        morpho.updateIndexes(aDai);

        // Should update the unclaimed amount
        vaultSupplier1.redeemVault(
            daiSupplyVault,
            daiSupplyVault.balanceOf(address(vaultSupplier1)),
            address(vaultSupplier2),
            address(vaultSupplier1)
        );
        (, uint128 userReward1_1) = daiSupplyVault.userRewards(
            rewardToken,
            address(vaultSupplier1)
        );

        vm.warp(block.timestamp + 10 days);

        uint256 userReward1_2 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier1),
            rewardToken
        );
        uint256 userReward2 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier2),
            rewardToken
        );

        (uint128 index2, ) = daiSupplyVault.userRewards(rewardToken, address(vaultSupplier2));
        assertEq(index2, 0);
        assertEq(userReward2, 0);
        assertGt(uint256(userReward1_1), 0);
        assertApproxEqAbs(uint256(userReward1_1), expectedTotalRewardsAmount, 10000);
        assertApproxEqAbs(uint256(userReward1_1), userReward1_2, 1);
    }

    function testRewardsShouldAccrueWhenWithdrawingToReceiver() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokens,
            address(daiSupplyVault),
            rewardToken
        );
        morpho.updateIndexes(aDai);

        // Should update the unclaimed amount
        vaultSupplier1.withdrawVault(
            daiSupplyVault,
            daiSupplyVault.maxWithdraw(address(vaultSupplier1)),
            address(vaultSupplier2),
            address(vaultSupplier1)
        );

        (, uint128 userReward1_1) = daiSupplyVault.userRewards(
            rewardToken,
            address(vaultSupplier1)
        );

        vm.warp(block.timestamp + 10 days);

        uint256 userReward1_2 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier1),
            rewardToken
        );
        uint256 userReward2 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier2),
            rewardToken
        );

        (uint128 index2, ) = daiSupplyVault.userRewards(rewardToken, address(vaultSupplier2));
        assertEq(index2, 0);
        assertEq(userReward2, 0);
        assertGt(uint256(userReward1_1), 0);
        assertApproxEqAbs(uint256(userReward1_1), expectedTotalRewardsAmount, 10000);
        assertApproxEqAbs(uint256(userReward1_1), userReward1_2, 1);
    }

    function testTransfer() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        uint256 balance = daiSupplyVault.balanceOf(address(vaultSupplier1));
        vm.prank(address(vaultSupplier1));
        daiSupplyVault.transfer(address(vaultSupplier2), balance);

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0);
        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier2)), balance);
    }

    function testTransferFrom() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        uint256 balance = daiSupplyVault.balanceOf(address(vaultSupplier1));
        vm.prank(address(vaultSupplier1));
        daiSupplyVault.approve(address(vaultSupplier3), balance);

        vm.prank(address(vaultSupplier3));
        daiSupplyVault.transferFrom(address(vaultSupplier1), address(vaultSupplier2), balance);

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0);
        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier2)), balance);
    }

    function testTransferAccrueRewards() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 balance = daiSupplyVault.balanceOf(address(vaultSupplier1));
        vm.prank(address(vaultSupplier1));
        daiSupplyVault.transfer(address(vaultSupplier2), balance);

        uint256 rewardAmount = ERC20(rewardToken).balanceOf(address(daiSupplyVault));
        uint256 expectedIndex = rewardAmount.rayDiv(daiSupplyVault.totalSupply());
        uint256 rewardsIndex = daiSupplyVault.rewardsIndex(rewardToken);
        assertEq(expectedIndex, rewardsIndex);

        (uint256 index1, uint256 unclaimed1) = daiSupplyVault.userRewards(
            rewardToken,
            address(vaultSupplier1)
        );
        assertEq(index1, rewardsIndex);
        assertEq(unclaimed1, rewardAmount);

        (uint256 index2, uint256 unclaimed2) = daiSupplyVault.userRewards(
            rewardToken,
            address(vaultSupplier2)
        );
        assertEq(index2, rewardsIndex);
        assertEq(unclaimed2, 0);

        (, uint256[] memory rewardsAmount1) = daiSupplyVault.claimRewards(address(vaultSupplier1));
        (, uint256[] memory rewardsAmount2) = daiSupplyVault.claimRewards(address(vaultSupplier2));
        assertGt(rewardsAmount1[0], 0, "rewardsAmount1");
        assertEq(rewardsAmount2[0], 0);
    }

    function testTransferFromAccrueRewards() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 balance = daiSupplyVault.balanceOf(address(vaultSupplier1));
        vm.prank(address(vaultSupplier1));
        daiSupplyVault.approve(address(vaultSupplier3), balance);

        vm.prank(address(vaultSupplier3));
        daiSupplyVault.transferFrom(address(vaultSupplier1), address(vaultSupplier2), balance);

        uint256 rewardAmount = ERC20(rewardToken).balanceOf(address(daiSupplyVault));
        uint256 expectedIndex = rewardAmount.rayDiv(daiSupplyVault.totalSupply());
        uint256 rewardsIndex = daiSupplyVault.rewardsIndex(rewardToken);
        assertEq(rewardsIndex, expectedIndex);

        (uint256 index1, uint256 unclaimed1) = daiSupplyVault.userRewards(
            rewardToken,
            address(vaultSupplier1)
        );
        assertEq(index1, rewardsIndex);
        assertEq(unclaimed1, rewardAmount);

        (uint256 index2, uint256 unclaimed2) = daiSupplyVault.userRewards(
            rewardToken,
            address(vaultSupplier2)
        );
        assertEq(index2, rewardsIndex);
        assertEq(unclaimed2, 0);

        (uint256 index3, uint256 unclaimed3) = daiSupplyVault.userRewards(
            rewardToken,
            address(vaultSupplier3)
        );
        assertEq(index3, 0);
        assertEq(unclaimed3, 0);

        (, uint256[] memory rewardsAmount1) = daiSupplyVault.claimRewards(address(vaultSupplier1));
        (, uint256[] memory rewardsAmount2) = daiSupplyVault.claimRewards(address(vaultSupplier2));
        (, uint256[] memory rewardsAmount3) = daiSupplyVault.claimRewards(address(vaultSupplier3));
        assertGt(rewardsAmount1[0], 0, "rewardsAmount1");
        assertEq(rewardsAmount2[0], 0);
        assertEq(rewardsAmount3[0], 0);
    }

    function testTransferAndClaimRewards() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        vaultSupplier2.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 balance = daiSupplyVault.balanceOf(address(vaultSupplier1));
        vm.prank(address(vaultSupplier1));
        daiSupplyVault.transfer(address(vaultSupplier2), balance);

        vm.warp(block.timestamp + 10 days);

        uint256 rewardsAmount1 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier1),
            rewardToken
        );
        uint256 rewardsAmount2 = daiSupplyVault.getUnclaimedRewards(
            address(vaultSupplier2),
            rewardToken
        );

        assertGt(rewardsAmount1, 0);
        assertApproxEqAbs(rewardsAmount1, (2 * rewardsAmount2) / 3, rewardsAmount1 / 100);
        // Why rewardsAmount1 is 2/3 of rewardsAmount2 can be explained as follows:
        // vaultSupplier1 first gets X rewards corresponding to amount over one period of time
        // vaultSupplier1 then and vaultSupplier2 get X rewards each (under the approximation that doubling the amount doubles the rewards)
        // vaultSupplier2 then gets 2 * X rewards
        // In the end, vaultSupplier1 got 2 * X rewards while vaultSupplier2 got 3 * X
    }

    // TODO: fix this test by using updated indexes in previewMint
    // function testShouldMintCorrectAmountWhenMorphoPoolIndexesOutdated() public {
    //     uint256 amount = 10_000 ether;

    //     vaultSupplier1.depositVault(daiSupplyVault, amount);

    //     vm.roll(block.number + 100_000);
    //     vm.warp(block.timestamp + 1_000_000);

    //     uint256 assets = vaultSupplier2.mintVault(daiSupplyVault, amount);
    //     uint256 shares = vaultSupplier2.withdrawVault(daiSupplyVault, assets);

    //     assertEq(shares, amount, "unexpected redeemed shares");
    // }

    function testShouldDepositCorrectAmountWhenMorphoPoolIndexesOutdated() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100_000);
        vm.warp(block.timestamp + 1_000_000);

        uint256 shares = vaultSupplier2.depositVault(daiSupplyVault, amount);
        uint256 assets = vaultSupplier2.redeemVault(daiSupplyVault, shares);

        assertApproxEqAbs(assets, amount, 1, "unexpected withdrawn assets");
    }

    function testShouldRedeemAllAmountWhenMorphoPoolIndexesOutdated() public {
        uint256 amount = 10_000 ether;

        uint256 expectedOnPool = amount.rayDiv(pool.getReserveNormalizedIncome(dai));

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100_000);
        vm.warp(block.timestamp + 1_000_000);

        uint256 assets = vaultSupplier1.redeemVault(daiSupplyVault, shares);

        assertEq(
            assets,
            expectedOnPool.rayMul(pool.getReserveNormalizedIncome(dai)),
            "unexpected withdrawn assets"
        );
    }

    function testShouldWithdrawAllAmountWhenMorphoPoolIndexesOutdated() public {
        uint256 amount = 10_000 ether;

        uint256 expectedOnPool = amount.rayDiv(pool.getReserveNormalizedIncome(dai));

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100_000);
        vm.warp(block.timestamp + 1_000_000);

        vaultSupplier1.withdrawVault(
            daiSupplyVault,
            expectedOnPool.rayMul(pool.getReserveNormalizedIncome(dai))
        );

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            address(aUsdc),
            address(daiSupplyVault)
        );

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcUSDT balance not zero");
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }
}
