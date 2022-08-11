// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyHarvestVault is TestSetupVaults {
    using WadRayMath for uint256;

    function testInitializationShouldRevertWithWrongInputs() public {
        SupplyHarvestVault supplyHarvestVaultImpl = new SupplyHarvestVault();

        SupplyHarvestVault vault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImpl),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        vm.expectRevert(abi.encodeWithSelector(SupplyVaultUpgradeable.ZeroAddress.selector));
        vault.initialize(address(0), aWrappedNativeToken, "test", "test", 0, 0, address(swapper));

        vm.expectRevert(abi.encodeWithSelector(SupplyVaultUpgradeable.ZeroAddress.selector));
        vault.initialize(address(morpho), address(0), "test", "test", 0, 0, address(swapper));

        vm.expectRevert(abi.encodeWithSelector(SupplyVaultUpgradeable.ZeroAddress.selector));
        vault.initialize(address(morpho), aWrappedNativeToken, "test", "test", 0, 0, address(0));

        uint16 moreThanMaxBasisPoints = vault.MAX_BASIS_POINTS() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyHarvestVault.ExceedsMaxBasisPoints.selector,
                moreThanMaxBasisPoints
            )
        );
        vault.initialize(
            address(morpho),
            aWrappedNativeToken,
            "test",
            "test",
            0,
            moreThanMaxBasisPoints,
            address(swapper)
        );
    }

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

        vm.expectRevert("ERC4626: redeem more than max");
        vaultSupplier2.redeemVault(daiSupplyHarvestVault, shares);
    }

    function testShouldNotWithdrawOnBehalfIfNotAllowed() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        vaultSupplier1.redeemVault(daiSupplyHarvestVault, shares, address(vaultSupplier2));
    }

    function testShouldWithdrawOnBehalfIfAllowed() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vaultSupplier1.approve(address(mahDai), address(vaultSupplier2), shares);
        vaultSupplier2.redeemVault(daiSupplyHarvestVault, shares, address(vaultSupplier1));
    }

    function testShouldNotMintZeroShare() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        vaultSupplier1.mintVault(daiSupplyHarvestVault, 0);
    }

    function testShouldNotWithdrawGreaterAmount() public {
        uint256 amount = 10000 ether;

        vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC4626: withdraw more than max");
        vaultSupplier1.withdrawVault(daiSupplyHarvestVault, amount * 2);
    }

    function testShouldNotRedeemMoreShares() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        vaultSupplier1.redeemVault(daiSupplyHarvestVault, shares + 1);
    }

    function testShouldClaimAndFoldRewards() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.warp(block.timestamp + 10 days);

        morpho.updateIndexes(aDai);
        (, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyHarvestVault)
        );

        (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256 totalSupplied,
            uint256 totalRewardsFee
        ) = daiSupplyHarvestVault.harvest();

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], rewardToken);
        assertEq(rewardsAmounts.length, 1);

        uint256 harvestingFee = daiSupplyHarvestVault.harvestingFee();
        uint256 expectedRewardsFee = (rewardsAmounts[0] * harvestingFee) /
            (daiSupplyHarvestVault.MAX_BASIS_POINTS() - harvestingFee);

        (, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyHarvestVault)
        );

        assertGt(totalSupplied, 0, "total supplied is zero");
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
        assertApproxEqAbs(totalRewardsFee, expectedRewardsFee, 1, "unexpected rewards fee amount");
        assertEq(ERC20(dai).balanceOf(address(this)), totalRewardsFee, "unexpected fee collected");
    }

    function testShouldClaimAndRedeemRewards() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.warp(block.timestamp + 10 days);

        morpho.updateIndexes(aDai);
        (, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyHarvestVault)
        );
        uint256 balanceBefore = vaultSupplier1.balanceOf(dai);

        (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256 totalSupplied,
            uint256 totalRewardsFee
        ) = daiSupplyHarvestVault.harvest();

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], rewardToken);
        assertEq(rewardsAmounts.length, 1);

        uint256 harvestingFee = daiSupplyHarvestVault.harvestingFee();
        uint256 expectedRewardsFee = (rewardsAmounts[0] * harvestingFee) /
            (daiSupplyHarvestVault.MAX_BASIS_POINTS() - harvestingFee);

        vaultSupplier1.redeemVault(daiSupplyHarvestVault, shares);
        uint256 balanceAfter = vaultSupplier1.balanceOf(dai);

        assertGt(totalSupplied, 0, "total supplied is zero");
        assertGt(rewardsAmounts[0], 0, "rewards amount is zero");
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
        assertApproxEqAbs(totalRewardsFee, expectedRewardsFee, 1, "unexpected rewards fee amount");
        assertEq(ERC20(dai).balanceOf(address(this)), totalRewardsFee, "unexpected fee collected");
    }

    /// GOVERNANCE ///

    function testOnlyOwnerShouldSetHarvestingFee() public {
        vm.prank(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyHarvestVault.setHarvestingFee(1);

        daiSupplyHarvestVault.setHarvestingFee(1);
        assertEq(daiSupplyHarvestVault.harvestingFee(), 1);
    }

    function testOnlyOwnerShouldSetSwapper() public {
        vm.prank(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyHarvestVault.setSwapper(address(1));

        daiSupplyHarvestVault.setSwapper(address(1));
        assertEq(address(daiSupplyHarvestVault.swapper()), address(1));
    }

    /// SETTERS ///

    function testShouldNotSetHarvestingFeeTooLarge() public {
        uint16 newVal = daiSupplyHarvestVault.MAX_BASIS_POINTS() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(SupplyHarvestVault.ExceedsMaxBasisPoints.selector, newVal)
        );
        daiSupplyHarvestVault.setHarvestingFee(newVal);
    }
}
