// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "../setup/TestSetupVaultsLive.sol";

contract TestEthLive is TestSetupVaultsLive {
    using PercentageMath for uint256;
    using CompoundMath for uint256;

    function testShouldDepositEthOnVault() public {
        uint256 amount = 100 ether;
        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cEth,
            address(wethSupplyHarvestVault)
        );

        vaultSupplier1.depositVault(wethSupplyHarvestVault, amount);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cEth,
            address(wethSupplyHarvestVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cEth);
        uint256 poolSupplyIndex = ICToken(cEth).exchangeRateCurrent();

        assertApproxEqAbs(
            balanceInP2P.mul(p2pSupplyIndex) + balanceOnPool.mul(poolSupplyIndex),
            balanceInP2PBefore.mul(p2pSupplyIndex) +
                balanceOnPoolBefore.mul(poolSupplyIndex) +
                amount,
            1e10
        );
    }

    function testShouldWithdrawEthOnVault() public {
        uint256 amount = 1 ether;

        uint256 poolSupplyIndex = ICToken(cEth).exchangeRateCurrent();
        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cEth);
        uint256 expectedOnPool = amount.div(poolSupplyIndex);
        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cEth,
            address(wethSupplyHarvestVault)
        );

        uint256 balanceBefore = vaultSupplier1.balanceOf(wEth);
        vaultSupplier1.depositVault(wethSupplyHarvestVault, amount);
        vaultSupplier1.withdrawVault(wethSupplyHarvestVault, expectedOnPool.mul(poolSupplyIndex));
        uint256 balanceAfter = vaultSupplier1.balanceOf(wEth);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cEth,
            address(wethSupplyHarvestVault)
        );

        assertApproxEqAbs(
            balanceInP2P.mul(p2pSupplyIndex) + balanceOnPool.mul(poolSupplyIndex),
            balanceInP2PBefore.mul(p2pSupplyIndex) + balanceOnPoolBefore.mul(poolSupplyIndex),
            100
        );
        assertApproxEqAbs(balanceAfter, balanceBefore, 1e9);
    }

    function testShouldClaimAndFoldRewardsOnEthVault() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(wethSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        morpho.updateP2PIndexes(cEth);
        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cEth,
            address(wethSupplyHarvestVault)
        );
        uint256 poolSupplyIndex = ICToken(cEth).exchangeRateCurrent();
        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cEth);
        (uint256 rewardsAmount, uint256 rewardsFee) = wethSupplyHarvestVault.harvest();
        uint256 expectedRewardsFee = (rewardsAmount + rewardsFee).percentMul(
            wethSupplyHarvestVault.harvestingFee()
        );

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cEth,
            address(wethSupplyHarvestVault)
        );

        assertGt(rewardsAmount, 0, "rewards amount is zero");
        assertApproxEqAbs(
            balanceOnPoolAfter.mul(poolSupplyIndex) + balanceInP2PAfter.mul(p2pSupplyIndex),
            balanceOnPoolBefore.mul(poolSupplyIndex) +
                balanceInP2PBefore.mul(p2pSupplyIndex) +
                rewardsAmount,
            rewardsAmount / 10,
            "unexpected balance"
        );
        assertEq(
            ERC20(comp).balanceOf(address(wethSupplyHarvestVault)),
            0,
            "comp amount is not zero"
        );
        assertEq(rewardsFee, expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(ERC20(wEth).balanceOf(address(this)), rewardsFee, "unexpected fee collected");
    }
}
