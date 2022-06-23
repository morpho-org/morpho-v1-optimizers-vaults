// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./TestSetupVaults.sol";

contract TestEth is TestSetupVaults {
    using CompoundMath for uint256;

    function testShouldDepositEthOnVault() public {
        uint256 toSupply = 100 ether;

        uint256 poolSupplyIndex = ICToken(cEth).exchangeRateCurrent();
        uint256 expectedOnPool = toSupply.div(poolSupplyIndex);

        uint256 balanceBefore = supplier1.balanceOf(wEth);
        supplier1.approve(wEth, address(wEthSupplyHarvestVault), toSupply);
        supplier1.depositVault(wEthSupplyHarvestVault, toSupply);
        uint256 balanceAfter = supplier1.balanceOf(wEth);

        testEquality(ERC20(cEth).balanceOf(address(morpho)), expectedOnPool, "balance of cToken");

        (uint256 inP2P, uint256 onPool) = morpho.supplyBalanceInOf(
            cEth,
            address(wEthSupplyHarvestVault)
        );

        assertEq(inP2P, 0);
        testEquality(onPool, expectedOnPool);
        testEquality(balanceAfter, balanceBefore - toSupply);
    }

    function testShouldWithdrawEthOnVault() public {
        uint256 toSupply = 1 ether;

        uint256 poolSupplyIndex = ICToken(cEth).exchangeRateCurrent();
        uint256 expectedOnPool = toSupply.div(poolSupplyIndex);

        uint256 balanceBefore = supplier1.balanceOf(wEth);
        supplier1.approve(wEth, address(wEthSupplyHarvestVault), toSupply);
        supplier1.depositVault(wEthSupplyHarvestVault, toSupply);
        supplier1.withdrawVault(wEthSupplyHarvestVault, expectedOnPool.mul(poolSupplyIndex));
        uint256 balanceAfter = supplier1.balanceOf(wEth);

        (uint256 inP2P, uint256 onPool) = morpho.supplyBalanceInOf(
            cEth,
            address(wEthSupplyHarvestVault)
        );

        assertEq(onPool, 0);
        assertEq(inP2P, 0);
        assertApproxEq(balanceAfter, balanceBefore, 1e9);
    }

    function testShouldClaimAndFoldRewardsOnEthVault() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(wEth, address(wEthSupplyHarvestVault), amount);
        supplier1.depositVault(wEthSupplyHarvestVault, amount);

        hevm.roll(block.number + 1_000);

        morpho.updateP2PIndexes(cEth);
        (, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cEth,
            address(wEthSupplyHarvestVault)
        );

        (uint256 rewardsAmount, uint256 rewardsFee) = wEthSupplyHarvestVault.harvest(
            wEthSupplyHarvestVault.maxHarvestingSlippage()
        );
        uint256 expectedRewardsFee = ((rewardsAmount + rewardsFee) *
            wEthSupplyHarvestVault.harvestingFee()) / wEthSupplyHarvestVault.MAX_BASIS_POINTS();

        (, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cEth,
            address(wEthSupplyHarvestVault)
        );

        assertGt(rewardsAmount, 0, "rewards amount is zero");
        assertEq(
            balanceOnPoolAfter,
            balanceOnPoolBefore + rewardsAmount.div(ICToken(cEth).exchangeRateCurrent()),
            "unexpected balance on pool"
        );
        assertEq(
            ERC20(comp).balanceOf(address(wEthSupplyHarvestVault)),
            0,
            "comp amount is not zero"
        );
        assertEq(rewardsFee, expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(ERC20(wEth).balanceOf(address(this)), rewardsFee, "unexpected fee collected");
    }
}
