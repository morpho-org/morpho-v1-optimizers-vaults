// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestEth is TestSetupVaults {
    using WadRayMath for uint256;

    function testShouldDepositEthOnVault() public {
        uint256 amount = 100 ether;

        vaultSupplier1.depositVault(wethSupplyHarvestVault, amount);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aWeth,
            address(wethSupplyHarvestVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(aWeth);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(wEth);

        assertApproxEqAbs(
            balanceInP2P.rayMul(p2pSupplyIndex) + balanceOnPool.rayMul(poolSupplyIndex),
            amount,
            1e10
        );
    }

    function testShouldWithdrawethOnVault() public {
        uint256 amount = 1 ether;

        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(wEth);
        uint256 expectedOnPool = amount.rayDiv(poolSupplyIndex);

        uint256 balanceBefore = vaultSupplier1.balanceOf(wEth);
        vaultSupplier1.depositVault(wethSupplyHarvestVault, amount);
        vaultSupplier1.withdrawVault(
            wethSupplyHarvestVault,
            expectedOnPool.rayMul(poolSupplyIndex)
        );
        uint256 balanceAfter = vaultSupplier1.balanceOf(wEth);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aWeth,
            address(wethSupplyHarvestVault)
        );

        assertEq(balanceInP2P, 0);
        assertEq(balanceOnPool, 0);
        assertApproxEqAbs(balanceAfter, balanceBefore, 1e9);
    }

    function testShouldClaimAndFoldRewardsOnEthVault() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(wethSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        morpho.updateIndexes(aWeth);
        (, uint256 balanceOnPoolbefore) = morpho.supplyBalanceInOf(
            aWeth,
            address(wethSupplyHarvestVault)
        );

        (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256[] memory rewardsFees
        ) = wethSupplyHarvestVault.harvest(wethSupplyHarvestVault.maxHarvestingSlippage());

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], rewardToken);
        assertEq(rewardsAmounts.length, 1);
        assertEq(rewardsFees.length, 1);

        uint256 expectedRewardsFee = ((rewardsAmounts[0] + rewardsFees[0]) *
            wethSupplyHarvestVault.harvestingFee()) / wethSupplyHarvestVault.MAX_BASIS_POINTS();

        (, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            aWeth,
            address(wethSupplyHarvestVault)
        );

        assertGt(rewardsAmounts[0], 0, "rewards amount is zero");
        assertEq(
            balanceOnPoolAfter,
            balanceOnPoolbefore + rewardsAmounts[0].rayDiv(pool.getReserveNormalizedIncome(wEth)),
            "unexpected balance on pool"
        );
        assertEq(
            ERC20(rewardToken).balanceOf(address(wethSupplyHarvestVault)),
            0,
            "rewardToken amount is not zero"
        );
        assertEq(rewardsFees[0], expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(ERC20(wEth).balanceOf(address(this)), rewardsFees[0], "unexpected fee collected");
    }
}
