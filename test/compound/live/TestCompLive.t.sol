// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "../setup/TestSetupVaultsLive.sol";

contract TestCompLive is TestSetupVaultsLive {
    using CompoundMath for uint256;

    function testShouldDepositCompOnVault() public {
        uint256 amount = 100 ether;
        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cComp,
            address(compSupplyHarvestVault)
        );

        vaultSupplier1.depositVault(compSupplyHarvestVault, amount);

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cComp,
            address(compSupplyHarvestVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cComp);
        uint256 poolSupplyIndex = ICToken(cComp).exchangeRateCurrent();

        assertApproxEqAbs(
            balanceInP2PAfter.mul(p2pSupplyIndex) + balanceOnPoolAfter.mul(poolSupplyIndex),
            balanceInP2PBefore.mul(p2pSupplyIndex) +
                balanceOnPoolBefore.mul(poolSupplyIndex) +
                amount,
            1e10
        );
    }

    function testShouldWithdrawCompOnVault() public {
        uint256 amount = 1 ether;

        uint256 poolSupplyIndex = ICToken(cComp).exchangeRateCurrent();
        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cComp);

        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cComp,
            address(compSupplyHarvestVault)
        );

        uint256 balanceBefore = vaultSupplier1.balanceOf(comp);
        vaultSupplier1.depositVault(compSupplyHarvestVault, amount);
        vaultSupplier1.withdrawVault(compSupplyHarvestVault, expectedOnPool.mul(poolSupplyIndex));
        uint256 balanceAfter = vaultSupplier1.balanceOf(comp);

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cComp,
            address(compSupplyHarvestVault)
        );

        assertApproxEqAbs(
            balanceInP2PBefore.mul(p2pSupplyIndex) + balanceOnPoolBefore.mul(poolSupplyIndex),
            balanceInP2PAfter.mul(p2pSupplyIndex) + balanceOnPoolAfter.mul(poolSupplyIndex),
            1 gwei
        );
        assertApproxEqAbs(balanceAfter, balanceBefore, 1e9);
    }

    function testShouldClaimAndFoldRewardsOnCompVault() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(compSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        morpho.updateP2PIndexes(cComp);
        (, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cComp,
            address(compSupplyHarvestVault)
        );

        (uint256 rewardsAmount, uint256 rewardsFee) = compSupplyHarvestVault.harvest(address(2));

        (, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cComp,
            address(compSupplyHarvestVault)
        );

        uint256 harvestingFee = compSupplyHarvestVault.harvestingFee();
        uint256 expectedRewardsFee = (rewardsAmount * harvestingFee) /
            (compSupplyHarvestVault.MAX_BASIS_POINTS() - harvestingFee);

        assertGt(rewardsFee, 0);
        assertGt(rewardsAmount, 0);
        assertEq(
            ERC20(comp).balanceOf(address(compSupplyHarvestVault)),
            0,
            "non zero comp balance on vault"
        );
        assertEq(
            balanceOnPoolAfter,
            balanceOnPoolBefore + rewardsAmount.div(ICToken(cComp).exchangeRateCurrent()),
            "unexpected balance on pool"
        );
        assertApproxEqAbs(rewardsFee, expectedRewardsFee, 1, "unexpected rewards fee");
        assertEq(ERC20(comp).balanceOf(address(2)), rewardsFee, "unexpected fee collected");
    }
}
