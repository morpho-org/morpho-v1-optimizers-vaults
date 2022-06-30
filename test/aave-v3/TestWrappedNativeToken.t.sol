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

        vm.roll(block.number + 1_000);

        morpho.updateIndexes(aWrappedNativeToken);
        (, uint256 balanceOnPoolbefore) = morpho.supplyBalanceInOf(
            aWrappedNativeToken,
            address(wrappedNativeTokenSupplyHarvestVault)
        );

        (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256[] memory rewardsFees
        ) = wrappedNativeTokenSupplyHarvestVault.harvest(
            wrappedNativeTokenSupplyHarvestVault.maxHarvestingSlippage()
        );

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], rewardToken);
        assertEq(rewardsAmounts.length, 1);
        assertEq(rewardsFees.length, 1);

        uint256 expectedRewardsFee = ((rewardsAmounts[0] + rewardsFees[0]) *
            wrappedNativeTokenSupplyHarvestVault.harvestingFee()) /
            wrappedNativeTokenSupplyHarvestVault.MAX_BASIS_POINTS();

        (, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            aWrappedNativeToken,
            address(wrappedNativeTokenSupplyHarvestVault)
        );

        assertGt(rewardsAmounts[0], 0, "rewards amount is zero");
        assertEq(
            balanceOnPoolAfter,
            balanceOnPoolbefore +
                rewardsAmounts[0].rayDiv(pool.getReserveNormalizedIncome(wrappedNativeToken)),
            "unexpected balance on pool"
        );
        assertEq(
            ERC20(rewardToken).balanceOf(address(wrappedNativeTokenSupplyHarvestVault)),
            0,
            "rewardToken amount is not zero"
        );
        assertEq(rewardsFees[0], expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(
            ERC20(wrappedNativeToken).balanceOf(address(this)),
            rewardsFees[0],
            "unexpected fee collected"
        );
    }
}
