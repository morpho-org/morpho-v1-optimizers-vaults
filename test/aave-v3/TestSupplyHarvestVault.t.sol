// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyHarvestVault is TestSetupVaults {
    using WadRayMath for uint256;

    function testShouldDepositAmount() public {
        uint256 amount = 10000 ether;

        vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyHarvestVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(aDai);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(dai);

        assertGt(
            daiSupplyHarvestVault.balanceOf(address(vaultSupplier1)),
            0,
            "mchDAI balance is zero"
        );
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

        vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);
        vaultSupplier1.withdrawVault(daiSupplyHarvestVault, expectedOnPool.rayMul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyHarvestVault)
        );

        assertApproxEqAbs(
            daiSupplyHarvestVault.balanceOf(address(vaultSupplier1)),
            0,
            1e3,
            "mcDAI balance not zero"
        );
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllUsdcAmount() public {
        uint256 amount = 1000e6;

        (, uint256 initialDepositOnPool) = morpho.supplyBalanceInOf(
            aUsdc,
            address(usdcSupplyHarvestVault)
        );

        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(usdc);
        uint256 expectedOnPool = amount.rayDiv(poolSupplyIndex);

        vaultSupplier1.depositVault(usdcSupplyHarvestVault, amount);
        vaultSupplier1.withdrawVault(
            usdcSupplyHarvestVault,
            expectedOnPool.rayMul(poolSupplyIndex)
        );

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aUsdc,
            address(usdcSupplyHarvestVault)
        );

        assertEq(
            usdcSupplyHarvestVault.balanceOf(address(vaultSupplier1)),
            0,
            "maUSDC balance not zero"
        );
        assertApproxEqAbs(balanceOnPool, initialDepositOnPool, 1e4, "unexpected onPool amount");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllShares() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);
        vaultSupplier1.redeemVault(daiSupplyHarvestVault, shares); // cannot withdraw amount because of Compound rounding errors

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyHarvestVault)
        );

        assertEq(
            daiSupplyHarvestVault.balanceOf(address(vaultSupplier1)),
            0,
            "mcDAI balance not zero"
        );
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldNotWithdrawWhenNotDeposited() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vaultSupplier2.redeemVault(daiSupplyHarvestVault, shares);
    }

    function testShouldNotWithdrawOnBehalfIfNotAllowed() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC20: insufficient allowance");
        vaultSupplier1.redeemVault(daiSupplyHarvestVault, shares, address(vaultSupplier2));
    }

    function testShouldWithdrawOnBehalfIfAllowed() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vaultSupplier1.approve(address(mahDai), address(vaultSupplier2), shares);
        vaultSupplier2.redeemVault(daiSupplyHarvestVault, shares, address(vaultSupplier1));
    }

    function testShouldNotDepositZeroAmount() public {
        vm.expectRevert(abi.encodeWithSignature("ShareIsZero()"));
        vaultSupplier1.depositVault(daiSupplyHarvestVault, 0);
    }

    function testShouldNotMintZeroShare() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        vaultSupplier1.mintVault(daiSupplyHarvestVault, 0);
    }

    function testShouldNotWithdrawGreaterAmount() public {
        uint256 amount = 10000 ether;

        vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vaultSupplier1.withdrawVault(daiSupplyHarvestVault, amount * 2);
    }

    function testShouldNotRedeemMoreShares() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vaultSupplier1.redeemVault(daiSupplyHarvestVault, shares + 1);
    }

    function testShouldClaimAndFoldRewards() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        morpho.updateIndexes(aDai);
        (, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyHarvestVault)
        );

        (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256[] memory rewardsFees
        ) = daiSupplyHarvestVault.harvest(daiSupplyHarvestVault.maxHarvestingSlippage());

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], rewardToken);
        assertEq(rewardsAmounts.length, 1);
        assertEq(rewardsFees.length, 1);

        uint256 expectedRewardsFee = ((rewardsAmounts[0] + rewardsFees[0]) *
            daiSupplyHarvestVault.harvestingFee()) / daiSupplyHarvestVault.MAX_BASIS_POINTS();

        (, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyHarvestVault)
        );

        assertGt(rewardsAmounts[0], 0, "rewards amount is zero");
        assertEq(
            balanceOnPoolAfter,
            balanceOnPoolBefore + rewardsAmounts[0].rayDiv(pool.getReserveNormalizedIncome(dai)),
            "unexpected balance on pool"
        );
        assertEq(
            ERC20(rewardToken).balanceOf(address(daiSupplyHarvestVault)),
            0,
            "rewardToken amount is not zero"
        );
        assertEq(rewardsFees[0], expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(ERC20(dai).balanceOf(address(this)), rewardsFees[0], "unexpected fee collected");
    }

    function testShouldClaimAndRedeemRewards() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        morpho.updateIndexes(aDai);
        (, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyHarvestVault)
        );
        uint256 balanceBefore = vaultSupplier1.balanceOf(dai);

        (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256[] memory rewardsFees
        ) = daiSupplyHarvestVault.harvest(daiSupplyHarvestVault.maxHarvestingSlippage());

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], rewardToken);
        assertEq(rewardsAmounts.length, 1);
        assertEq(rewardsFees.length, 1);

        uint256 expectedRewardsFee = ((rewardsAmounts[0] + rewardsFees[0]) *
            daiSupplyHarvestVault.harvestingFee()) / daiSupplyHarvestVault.MAX_BASIS_POINTS();

        vaultSupplier1.redeemVault(daiSupplyHarvestVault, shares);
        uint256 balanceAfter = vaultSupplier1.balanceOf(dai);

        assertEq(
            ERC20(dai).balanceOf(address(daiSupplyHarvestVault)),
            0,
            "non zero dai balance on vault"
        );
        assertGt(
            balanceAfter,
            balanceBefore + balanceOnPoolBefore + rewardsAmounts[0],
            "unexpected dai balance"
        );
        assertEq(rewardsFees[0], expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(ERC20(dai).balanceOf(address(this)), rewardsFees[0], "unexpected fee collected");
    }

    function testShouldNotAllowOracleDumpManipulation() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        uint256 flashloanAmount = 1_000 ether;
        ISwapRouter swapRouter = daiSupplyHarvestVault.SWAP_ROUTER();

        deal(rewardToken, address(this), flashloanAmount);
        ERC20(rewardToken).approve(address(swapRouter), flashloanAmount);
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: rewardToken,
                tokenOut: wEth,
                fee: daiSupplyHarvestVault.rewardsSwapFee(rewardToken),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: flashloanAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        vm.expectRevert("Too little received");
        daiSupplyHarvestVault.harvest(100);
    }
}