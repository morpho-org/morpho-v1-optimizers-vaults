// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestEth is TestSetup {
    using CompoundMath for uint256;

    function testShouldDepositEthOnVault() public {
        uint256 amount = 100 ether;

        supplier1.approve(weth, address(wethSupplyHarvestVault), amount);
        supplier1.deposit(wethSupplyHarvestVault, amount);

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cEth),
            address(wethSupplyHarvestVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(address(cEth));
        uint256 poolSupplyIndex = cEth.exchangeRateCurrent();

        assertApproxEqAbs(
            supplyBalance.inP2P.mul(p2pSupplyIndex) + supplyBalance.onPool.mul(poolSupplyIndex),
            amount,
            1e10
        );
    }

    function testShouldWithdrawethOnVault() public {
        uint256 amount = 1 ether;

        uint256 poolSupplyIndex = cEth.exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        uint256 balanceBefore = supplier1.balanceOf(weth);
        supplier1.approve(weth, address(wethSupplyHarvestVault), amount);
        supplier1.deposit(wethSupplyHarvestVault, amount);
        supplier1.withdraw(wethSupplyHarvestVault, expectedOnPool.mul(poolSupplyIndex));
        uint256 balanceAfter = supplier1.balanceOf(weth);

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cEth),
            address(wethSupplyHarvestVault)
        );

        assertEq(supplyBalance.onPool, 0);
        assertEq(supplyBalance.inP2P, 0);
        assertApproxEqAbs(balanceAfter, balanceBefore, 1e9);
    }

    function testShouldClaimAndFoldRewardsOnEthVault() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(weth, address(wethSupplyHarvestVault), amount);
        supplier1.deposit(wethSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        morpho.updateP2PIndexes(address(cEth));
        Types.SupplyBalance memory supplyBalanceBefore = morpho.supplyBalanceInOf(
            address(cEth),
            address(wethSupplyHarvestVault)
        );

        (uint256 rewardsAmount, uint256 rewardsFee) = wethSupplyHarvestVault.harvest(
            wethSupplyHarvestVault.maxHarvestingSlippage()
        );
        uint256 expectedRewardsFee = ((rewardsAmount + rewardsFee) *
            wethSupplyHarvestVault.harvestingFee()) / wethSupplyHarvestVault.MAX_BASIS_POINTS();

        Types.SupplyBalance memory supplyBalanceAfter = morpho.supplyBalanceInOf(
            address(cEth),
            address(wethSupplyHarvestVault)
        );

        assertGt(rewardsAmount, 0, "rewards amount is zero");
        assertEq(
            supplyBalanceAfter.onPool,
            supplyBalanceBefore.onPool + rewardsAmount.div(cEth.exchangeRateCurrent()),
            "unexpected balance on pool"
        );
        assertEq(comp.balanceOf(address(wethSupplyHarvestVault)), 0, "comp amount is not zero");
        assertEq(rewardsFee, expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(weth.balanceOf(address(this)), rewardsFee, "unexpected fee collected");
    }
}
