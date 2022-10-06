// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestEth is TestSetupVaults {
    using PercentageMath for uint256;
    using CompoundMath for uint256;

    function testCorrectInitialisation() public {
        assertEq(wethSupplyHarvestVault.owner(), address(this));
        assertEq(wethSupplyHarvestVault.name(), "MorphoCompoundHarvestWETH");
        assertEq(wethSupplyHarvestVault.symbol(), "mchWETH");
        assertEq(wethSupplyHarvestVault.poolToken(), cEth);
        assertEq(wethSupplyHarvestVault.asset(), wEth);
        assertEq(wethSupplyHarvestVault.decimals(), 18);
        assertTrue(wethSupplyHarvestVault.isEth());
        assertEq(wethSupplyHarvestVault.compSwapFee(), 3000);
        assertEq(wethSupplyHarvestVault.assetSwapFee(), 0);
        assertEq(wethSupplyHarvestVault.harvestingFee(), 50);
    }

    function testShouldDepositEthOnVault() public {
        uint256 amount = 100 ether;

        vaultSupplier1.depositVault(wethSupplyHarvestVault, amount);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cEth,
            address(wethSupplyHarvestVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cEth);
        uint256 poolSupplyIndex = ICToken(cEth).exchangeRateCurrent();

        assertApproxEqAbs(
            balanceInP2P.mul(p2pSupplyIndex) + balanceOnPool.mul(poolSupplyIndex),
            amount,
            1e10
        );
    }

    function testShouldWithdrawethOnVault() public {
        uint256 amount = 1 ether;

        uint256 poolSupplyIndex = ICToken(cEth).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        uint256 balanceBefore = vaultSupplier1.balanceOf(wEth);
        vaultSupplier1.depositVault(wethSupplyHarvestVault, amount);
        vaultSupplier1.withdrawVault(wethSupplyHarvestVault, expectedOnPool.mul(poolSupplyIndex));
        uint256 balanceAfter = vaultSupplier1.balanceOf(wEth);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cEth,
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

        morpho.updateP2PIndexes(cEth);
        (, uint256 balanceOnPoolbefore) = morpho.supplyBalanceInOf(
            cEth,
            address(wethSupplyHarvestVault)
        );

        (uint256 rewardsAmount, uint256 rewardsFee) = wethSupplyHarvestVault.harvest(address(3));
        uint256 expectedRewardsFee = (rewardsAmount + rewardsFee).percentMul(
            wethSupplyHarvestVault.harvestingFee()
        );

        (, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cEth,
            address(wethSupplyHarvestVault)
        );

        assertGt(rewardsAmount, 0, "rewards amount is zero");
        assertEq(
            balanceOnPoolAfter,
            balanceOnPoolbefore + rewardsAmount.div(ICToken(cEth).exchangeRateCurrent()),
            "unexpected balance on pool"
        );
        assertEq(
            ERC20(comp).balanceOf(address(wethSupplyHarvestVault)),
            0,
            "comp amount is not zero"
        );
        assertEq(rewardsFee, expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(ERC20(wEth).balanceOf(address(3)), rewardsFee, "unexpected fee collected");
    }
}
