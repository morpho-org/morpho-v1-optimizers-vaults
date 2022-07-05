// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestWrappedNativeToken is TestSetupVaults {
    using WadRayMath for uint256;

    function testShouldDepositWrappedNativeTokenOnVault() public {
        uint256 amount = 100 ether;

        vaultSupplier1.depositVault(wrappedNativeTokenSupplyHarvestVault, amount);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aWrappedNativeToken,
            address(wrappedNativeTokenSupplyHarvestVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(aWrappedNativeToken);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(wrappedNativeToken);

        assertApproxEqAbs(
            balanceInP2P.rayMul(p2pSupplyIndex) + balanceOnPool.rayMul(poolSupplyIndex),
            amount,
            1e10
        );
    }

    function testShouldWithdrawWrappedNativeTokenOnVault() public {
        uint256 amount = 1 ether;

        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(wrappedNativeToken);
        uint256 expectedOnPool = amount.rayDiv(poolSupplyIndex);

        uint256 balanceBefore = vaultSupplier1.balanceOf(wrappedNativeToken);
        vaultSupplier1.depositVault(wrappedNativeTokenSupplyHarvestVault, amount);
        vaultSupplier1.withdrawVault(
            wrappedNativeTokenSupplyHarvestVault,
            expectedOnPool.rayMul(poolSupplyIndex)
        );
        uint256 balanceAfter = vaultSupplier1.balanceOf(wrappedNativeToken);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aWrappedNativeToken,
            address(wrappedNativeTokenSupplyHarvestVault)
        );

        assertEq(balanceInP2P, 0);
        assertEq(balanceOnPool, 0);
        assertApproxEqAbs(balanceAfter, balanceBefore, 1e9);
    }

    function testShouldClaimAndFoldRewardsOnWrappedNativeTokenVault() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(wrappedNativeTokenSupplyHarvestVault, amount);

        vm.warp(block.timestamp + 10 days);

        morpho.updateIndexes(aWrappedNativeToken);
        (, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            aWrappedNativeToken,
            address(wrappedNativeTokenSupplyHarvestVault)
        );

        (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256[] memory rewardsFees
        ) = wrappedNativeTokenSupplyHarvestVault.harvest();

        assertEq(rewardTokens.length, 1, "unexpected reward tokens length");
        assertEq(rewardTokens[0], rewardToken, "unexpected reward token");
        assertEq(rewardsAmounts.length, 1, "unexpected rewards amounts length");
        assertEq(rewardsFees.length, 1, "unexpected rewards fees length");

        (, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            aWrappedNativeToken,
            address(wrappedNativeTokenSupplyHarvestVault)
        );

        uint256 harvestingFee = wrappedNativeTokenSupplyHarvestVault.harvestingFee();
        uint256 expectedRewardsFee = (rewardsAmounts[0] * harvestingFee) /
            (wrappedNativeTokenSupplyHarvestVault.MAX_BASIS_POINTS() - harvestingFee);

        assertGt(rewardsFees[0], 0, "rewards fee is zero");
        assertGt(rewardsAmounts[0], 0, "rewards amount is zero");
        assertEq(
            balanceOnPoolAfter,
            balanceOnPoolBefore +
                rewardsAmounts[0].rayDiv(pool.getReserveNormalizedIncome(wrappedNativeToken)),
            "unexpected balance on pool"
        );
        assertEq(
            ERC20(rewardToken).balanceOf(address(wrappedNativeTokenSupplyHarvestVault)),
            0,
            "rewardToken amount is not zero"
        );
        assertEq(rewardsFees[0], expectedRewardsFee, "unexpected rewards fee");
        assertEq(
            ERC20(wrappedNativeToken).balanceOf(address(this)),
            rewardsFees[0],
            "unexpected fee collected"
        );
    }
}
