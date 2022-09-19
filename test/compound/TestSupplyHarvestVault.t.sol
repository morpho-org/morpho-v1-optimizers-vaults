// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyHarvestVault is TestSetupVaults {
    using CompoundMath for uint256;

    function testInitializationShouldRevertWithWrongInputs() public {
        SupplyHarvestVault supplyHarvestVaultImpl = new SupplyHarvestVault(address(morpho));

        SupplyHarvestVault vault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImpl),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        vm.expectRevert(abi.encodeWithSelector(SupplyVaultBase.ZeroAddress.selector));
        new SupplyHarvestVault(address(0));

        vm.expectRevert(abi.encodeWithSelector(SupplyVaultBase.ZeroAddress.selector));
        vault.initialize(
            address(0),
            "test",
            "test",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, 100)
        );

        uint16 moreThanMaxBasisPoints = vault.MAX_BASIS_POINTS() + 1;
        uint24 moreThanMaxUniswapFee = vault.MAX_UNISWAP_FEE() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyHarvestVault.ExceedsMaxUniswapV3Fee.selector,
                moreThanMaxUniswapFee
            )
        );
        vault.initialize(
            cDai,
            "test",
            "test",
            0,
            SupplyHarvestVault.HarvestConfig(moreThanMaxUniswapFee, 500, 100)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyHarvestVault.ExceedsMaxUniswapV3Fee.selector,
                moreThanMaxUniswapFee
            )
        );
        vault.initialize(
            cDai,
            "test",
            "test",
            0,
            SupplyHarvestVault.HarvestConfig(3000, moreThanMaxUniswapFee, 100)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyHarvestVault.ExceedsMaxBasisPoints.selector,
                moreThanMaxBasisPoints
            )
        );
        vault.initialize(
            cDai,
            "test",
            "test",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, moreThanMaxBasisPoints)
        );
    }

    function testShouldDepositAmount() public {
        uint256 amount = 10000 ether;

        vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyHarvestVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cDai);
        uint256 poolSupplyIndex = ICToken(cDai).exchangeRateCurrent();

        assertGt(
            daiSupplyHarvestVault.balanceOf(address(vaultSupplier1)),
            0,
            "mchDAI balance is zero"
        );
        assertApproxEqAbs(
            balanceInP2P.mul(p2pSupplyIndex) + balanceOnPool.mul(poolSupplyIndex),
            amount.div(poolSupplyIndex).mul(poolSupplyIndex),
            1e10
        );
    }

    function testShouldWithdrawAllAmount() public {
        uint256 amount = 10000 ether;

        uint256 poolSupplyIndex = ICToken(cDai).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);
        vaultSupplier1.withdrawVault(daiSupplyHarvestVault, expectedOnPool.mul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyHarvestVault)
        );

        assertApproxEqAbs(
            daiSupplyHarvestVault.balanceOf(address(vaultSupplier1)),
            0,
            2e3,
            "mcDAI balance not zero"
        );
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllUsdcAmount() public {
        uint256 amount = 1e9;

        uint256 poolSupplyIndex = ICToken(cUsdc).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        vaultSupplier1.depositVault(usdcSupplyHarvestVault, amount);
        vaultSupplier1.withdrawVault(usdcSupplyHarvestVault, expectedOnPool.mul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cUsdc,
            address(usdcSupplyHarvestVault)
        );

        assertEq(
            usdcSupplyHarvestVault.balanceOf(address(vaultSupplier1)),
            0,
            "mcUSDC balance not zero"
        );
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllShares() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);
        vaultSupplier1.redeemVault(daiSupplyHarvestVault, shares); // cannot withdraw amount because of Compound rounding errors

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cDai,
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

        vaultSupplier1.approve(address(mchDai), address(vaultSupplier2), shares);
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

        vm.roll(block.number + 1_000);

        morpho.updateP2PIndexes(cDai);
        (, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyHarvestVault)
        );

        (uint256 rewardsAmount, uint256 rewardsFee) = daiSupplyHarvestVault.harvest();

        uint256 harvestingFee = daiSupplyHarvestVault.harvestingFee();
        uint256 expectedRewardsFee = (rewardsAmount * harvestingFee) /
            (daiSupplyHarvestVault.MAX_BASIS_POINTS() - harvestingFee);

        (, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyHarvestVault)
        );

        assertGt(rewardsAmount, 0, "rewards amount is zero");
        assertEq(
            balanceOnPoolAfter,
            balanceOnPoolBefore + rewardsAmount.div(ICToken(cDai).exchangeRateCurrent()),
            "unexpected balance on pool"
        );
        assertEq(
            ERC20(comp).balanceOf(address(daiSupplyHarvestVault)),
            0,
            "comp amount is not zero"
        );
        assertApproxEqAbs(rewardsFee, expectedRewardsFee, 1, "unexpected rewards fee amount");
        assertEq(ERC20(dai).balanceOf(address(this)), rewardsFee, "unexpected fee collected");
    }

    function testShouldClaimAndRedeemRewards() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        morpho.updateP2PIndexes(cDai);
        (, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyHarvestVault)
        );
        uint256 balanceBefore = vaultSupplier1.balanceOf(dai);

        (uint256 rewardsAmount, uint256 rewardsFee) = daiSupplyHarvestVault.harvest();

        uint256 harvestingFee = daiSupplyHarvestVault.harvestingFee();
        uint256 expectedRewardsFee = (rewardsAmount * harvestingFee) /
            (daiSupplyHarvestVault.MAX_BASIS_POINTS() - harvestingFee);

        vaultSupplier1.redeemVault(daiSupplyHarvestVault, shares);
        uint256 balanceAfter = vaultSupplier1.balanceOf(dai);

        assertEq(
            ERC20(dai).balanceOf(address(daiSupplyHarvestVault)),
            0,
            "non zero dai balance on vault"
        );
        assertGt(
            balanceAfter,
            balanceBefore + balanceOnPoolBefore + rewardsAmount,
            "unexpected dai balance"
        );
        assertApproxEqAbs(rewardsFee, expectedRewardsFee, 1, "unexpected rewards fee amount");
        assertEq(ERC20(dai).balanceOf(address(this)), rewardsFee, "unexpected fee collected");
    }

    /// GOVERNANCE ///

    function testOnlyOwnerShouldSetCompSwapFee() public {
        vm.prank(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyHarvestVault.setCompSwapFee(1);

        daiSupplyHarvestVault.setCompSwapFee(1);
        assertEq(daiSupplyHarvestVault.compSwapFee(), 1);
    }

    function testOnlyOwnerShouldSetAssetSwapFee() public {
        vm.prank(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyHarvestVault.setAssetSwapFee(1);

        daiSupplyHarvestVault.setAssetSwapFee(1);
        assertEq(daiSupplyHarvestVault.assetSwapFee(), 1);
    }

    function testOnlyOwnerShouldSetHarvestingFee() public {
        vm.prank(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyHarvestVault.setHarvestingFee(1);

        daiSupplyHarvestVault.setHarvestingFee(1);
        assertEq(daiSupplyHarvestVault.harvestingFee(), 1);
    }

    function testNotOwnerShouldNotTransferTokens(uint256 _amount) public {
        vm.prank(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyHarvestVault.transferTokens($token, address(2), _amount);
    }

    function testOwnerShouldTransferTokens(
        address _to,
        uint256 _deal,
        uint256 _toTransfer
    ) public {
        _toTransfer = bound(_toTransfer, 0, _deal);
        deal($token, address(daiSupplyHarvestVault), _deal);

        vm.prank(daiSupplyHarvestVault.owner());
        daiSupplyHarvestVault.transferTokens($token, _to, _toTransfer);

        assertEq(token.balanceOf(address(daiSupplyHarvestVault)), _deal - _toTransfer);
        assertEq(token.balanceOf(_to), _toTransfer);
    }

    /// SETTERS ///

    function testShouldNotSetCompSwapFeeTooLarge() public {
        uint24 newVal = daiSupplyHarvestVault.MAX_UNISWAP_FEE() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(SupplyHarvestVault.ExceedsMaxUniswapV3Fee.selector, newVal)
        );
        daiSupplyHarvestVault.setCompSwapFee(newVal);
    }

    function testShouldNotSetAssetSwapFeeTooLarge() public {
        uint24 newVal = daiSupplyHarvestVault.MAX_UNISWAP_FEE() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(SupplyHarvestVault.ExceedsMaxUniswapV3Fee.selector, newVal)
        );
        daiSupplyHarvestVault.setAssetSwapFee(newVal);
    }

    function testShouldNotSetHarvestingFeeTooLarge() public {
        uint16 newVal = daiSupplyHarvestVault.MAX_BASIS_POINTS() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(SupplyHarvestVault.ExceedsMaxBasisPoints.selector, newVal)
        );
        daiSupplyHarvestVault.setHarvestingFee(newVal);
    }
}
