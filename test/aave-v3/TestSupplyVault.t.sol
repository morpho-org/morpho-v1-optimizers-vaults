// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyVault is TestSetupVaults {
    using WadRayMath for uint256;

    function testShouldDepositAmount() public {
        uint256 amount = 10000 ether;

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
        uint256 amount = 10000 ether;

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
        uint256 amount = 10000 ether;

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
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vaultSupplier2.redeemVault(daiSupplyVault, shares);
    }

    function testShouldNotWithdrawOnBehalfIfNotAllowed() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC20: insufficient allowance");
        vaultSupplier1.redeemVault(daiSupplyVault, shares, address(vaultSupplier2));
    }

    function testShouldWithdrawOnBehalfIfAllowed() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vaultSupplier1.approve(address(maDai), address(vaultSupplier2), shares);
        vaultSupplier2.redeemVault(daiSupplyVault, shares, address(vaultSupplier1));
    }

    function testShouldNotDepositZeroAmount() public {
        vm.expectRevert(abi.encodeWithSignature("ShareIsZero()"));
        vaultSupplier1.depositVault(daiSupplyVault, 0);
    }

    function testShouldNotMintZeroShare() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        vaultSupplier1.mintVault(daiSupplyVault, 0);
    }

    function testShouldNotWithdrawGreaterAmount() public {
        uint256 amount = 10000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vaultSupplier1.withdrawVault(daiSupplyVault, amount * 2);
    }

    function testShouldNotRedeemMoreShares() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vaultSupplier1.redeemVault(daiSupplyVault, shares + 1);
    }

    function testShouldClaimRewards() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 1_000);

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
        address[] memory poolTokenAddresses = new address[](1);
        poolTokenAddresses[0] = aDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokenAddresses,
            address(daiSupplyVault),
            rewardToken
        );

        vaultSupplier2.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokenAddresses,
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
            claimedAmounts1[0] + claimedAmounts2[0],
            expectedTotalRewardsAmount,
            1e5,
            "unexpected total rewards amount"
        );
        assertLt(claimedAmounts1[0] + claimedAmounts2[0], expectedTotalRewardsAmount);
        assertApproxEqAbs(
            claimedAmounts1[0],
            2 * claimedAmounts2[0],
            1e9,
            "unexpected rewards amount"
        ); // not exact because of rewardTokenounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration1() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokenAddresses = new address[](1);
        poolTokenAddresses[0] = aDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokenAddresses,
            address(daiSupplyVault),
            rewardToken
        );

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokenAddresses,
            address(daiSupplyVault),
            rewardToken
        );

        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokenAddresses,
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
            claimedAmounts1[0] + claimedAmounts2[0],
            expectedTotalRewardsAmount,
            1e5,
            "unexpected total rewards amount"
        );
        assertLt(claimedAmounts1[0] + claimedAmounts2[0], expectedTotalRewardsAmount);
        assertApproxEqAbs(claimedAmounts1[0], claimedAmounts2[0], 1e8, "unexpected rewards amount"); // not exact because of rewardTokenounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration2() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokenAddresses = new address[](1);
        poolTokenAddresses[0] = aDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserRewards(
            poolTokenAddresses,
            address(daiSupplyVault),
            rewardToken
        );

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokenAddresses,
            address(daiSupplyVault),
            rewardToken
        );

        uint256 shares3 = vaultSupplier3.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokenAddresses,
            address(daiSupplyVault),
            rewardToken
        );

        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);
        vaultSupplier3.redeemVault(daiSupplyVault, shares3 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += rewardsManager.getUserRewards(
            poolTokenAddresses,
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
            claimedAmounts1[0] + claimedAmounts2[0] + claimedAmounts3[0],
            expectedTotalRewardsAmount,
            1e5,
            "unexpected total rewards amount"
        );
        assertLt(
            claimedAmounts1[0] + claimedAmounts2[0] + claimedAmounts3[0],
            expectedTotalRewardsAmount
        );
        assertApproxEqAbs(
            ERC20(rewardToken).balanceOf(address(daiSupplyVault)),
            0,
            1e5,
            "non zero rewardToken balance on vault"
        );
        assertApproxEqAbs(
            claimedAmounts1[0],
            claimedAmounts2[0],
            1e9,
            "unexpected rewards amount 1-2"
        ); // not exact because of rewardTokenounded interests
        assertApproxEqAbs(
            claimedAmounts2[0],
            claimedAmounts3[0],
            1e8,
            "unexpected rewards amount 2-3"
        ); // not exact because of rewardTokenounded interests
    }
}