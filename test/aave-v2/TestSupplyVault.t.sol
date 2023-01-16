// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyVault is TestSetupVaults {
    using WadRayMath for uint256;

    function testCorrectInitialisationWeth() public {
        assertEq(wNativeSupplyVault.owner(), address(this));
        assertEq(wNativeSupplyVault.name(), "MorphoAave2WETH");
        assertEq(wNativeSupplyVault.symbol(), "ma2WETH");
        assertEq(wNativeSupplyVault.poolToken(), aWeth);
        assertEq(wNativeSupplyVault.asset(), wEth);
        assertEq(wNativeSupplyVault.decimals(), 18);
    }

    function testCorrectInitialisationDai() public {
        assertEq(daiSupplyVault.owner(), address(this));
        assertEq(daiSupplyVault.name(), "MorphoAave2DAI");
        assertEq(daiSupplyVault.symbol(), "ma2DAI");
        assertEq(daiSupplyVault.poolToken(), aDai);
        assertEq(daiSupplyVault.asset(), dai);
        assertEq(daiSupplyVault.decimals(), 18);
    }

    function testCorrectInitialisationUsdc() public {
        assertEq(usdcSupplyVault.owner(), address(this));
        assertEq(usdcSupplyVault.name(), "MorphoAave2USDC");
        assertEq(usdcSupplyVault.symbol(), "ma2USDC");
        assertEq(usdcSupplyVault.poolToken(), aUsdc);
        assertEq(usdcSupplyVault.asset(), usdc);
        assertEq(usdcSupplyVault.decimals(), 18);
    }

    function testShouldDepositAmount() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(aDai);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(dai);

        assertGt(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcDAI balance is zero");
        assertApproxEqAbs(
            balanceInP2P.rayMul(p2pSupplyIndex) + balanceOnPool.rayMul(poolSupplyIndex),
            amount.rayDiv(poolSupplyIndex).rayMul(poolSupplyIndex),
            1e10
        );
    }

    function testShouldWithdrawAllAmount() public {
        uint256 amount = 10_000 ether;

        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(dai);
        uint256 expectedOnPool = amount.rayDiv(poolSupplyIndex);

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.withdrawVault(daiSupplyVault, expectedOnPool.rayMul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        assertApproxEqAbs(
            daiSupplyVault.balanceOf(address(vaultSupplier1)),
            0,
            1e3,
            "mcDAI balance not zero"
        );
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllUsdcAmount() public {
        uint256 amount = 1e9;

        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(usdc);
        uint256 expectedOnPool = amount.rayDiv(poolSupplyIndex);

        vaultSupplier1.depositVault(usdcSupplyVault, amount);
        vaultSupplier1.withdrawVault(usdcSupplyVault, expectedOnPool.rayMul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            address(aUsdc),
            address(usdcSupplyVault)
        );

        assertApproxEqAbs(
            usdcSupplyVault.balanceOf(address(vaultSupplier1)),
            0,
            10,
            "mcUSDT balance not zero"
        );
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllShares() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares); // cannot withdraw amount because of Compound rounding errors

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcDAI balance not zero");
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldNotWithdrawWhenNotDeposited() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        vaultSupplier2.redeemVault(daiSupplyVault, shares);
    }

    function testShouldNotWithdrawOnBehalfIfNotAllowed() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        vaultSupplier1.redeemVault(daiSupplyVault, shares, address(vaultSupplier2));
    }

    function testShouldWithdrawOnBehalfIfAllowed() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vaultSupplier1.approve(address(ma2Dai), address(vaultSupplier2), shares);
        vaultSupplier2.redeemVault(daiSupplyVault, shares, address(vaultSupplier1));
    }

    function testShouldNotMintZeroShare() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        vaultSupplier1.mintVault(daiSupplyVault, 0);
    }

    function testShouldNotWithdrawGreaterAmount() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: withdraw more than max");
        vaultSupplier1.withdrawVault(daiSupplyVault, amount * 2);
    }

    function testShouldNotRedeemMoreShares() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        vaultSupplier1.redeemVault(daiSupplyVault, shares + 1);
    }

    function testShouldDepositCorrectAmountWhenMorphoPoolIndexesOutdated() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100_000);
        vm.warp(block.timestamp + 1_000_000);

        uint256 shares = vaultSupplier2.depositVault(daiSupplyVault, amount);
        uint256 assets = vaultSupplier2.redeemVault(daiSupplyVault, shares);

        assertApproxEqAbs(assets, amount, 1, "unexpected withdrawn assets");
    }

    function testShouldRedeemAllAmountWhenMorphoPoolIndexesOutdated() public {
        uint256 amount = 10_000 ether;

        uint256 expectedOnPool = amount.rayDiv(pool.getReserveNormalizedIncome(dai));

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100_000);
        vm.warp(block.timestamp + 1_000_000);

        uint256 assets = vaultSupplier1.redeemVault(daiSupplyVault, shares);

        assertEq(
            assets,
            expectedOnPool.rayMul(pool.getReserveNormalizedIncome(dai)),
            "unexpected withdrawn assets"
        );
    }

    function testShouldWithdrawAllAmountWhenMorphoPoolIndexesOutdated() public {
        uint256 amount = 10_000 ether;

        uint256 expectedOnPool = amount.rayDiv(pool.getReserveNormalizedIncome(dai));

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100_000);
        vm.warp(block.timestamp + 1_000_000);

        vaultSupplier1.withdrawVault(
            daiSupplyVault,
            expectedOnPool.rayMul(pool.getReserveNormalizedIncome(dai))
        );

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            address(aUsdc),
            address(daiSupplyVault)
        );

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcUSDT balance not zero");
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testPreviewMint() public {
        uint256 amount = 1e5 ether;

        uint256 balanceBefore1 = ERC20(dai).balanceOf(address(vaultSupplier1));
        uint256 balanceBefore2 = ERC20(dai).balanceOf(address(vaultSupplier2));

        vm.warp(block.timestamp + 1000);

        // This should test that using the lens' predicted indexes is the correct amount to use.
        uint256 preview1 = daiSupplyVault.previewMint(amount);
        vaultSupplier1.mintVault(daiSupplyVault, amount);
        assertEq(preview1, balanceBefore1 - ERC20(dai).balanceOf(address(vaultSupplier1)));

        // The mint interacts with Morpho which updates the indexes,
        // so this should test that the lens predicted index does not differ from Morpho's actual index
        uint256 preview2 = daiSupplyVault.previewMint(amount);
        vaultSupplier2.mintVault(daiSupplyVault, amount);
        assertEq(preview2, balanceBefore2 - ERC20(dai).balanceOf(address(vaultSupplier2)));
    }

    function testPreviewDeposit() public {
        uint256 amount = 1e5 ether;

        vm.warp(block.timestamp + 1000);

        // This should test that using the lens' predicted indexes is the correct amount to use.
        uint256 preview1 = daiSupplyVault.previewDeposit(amount);
        vaultSupplier1.depositVault(daiSupplyVault, amount);
        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), preview1, "before");

        // The deposit interacts with Morpho which updates the indexes,
        // so this should test that the lens predicted index does not differ from Morpho's actual index
        uint256 preview2 = daiSupplyVault.previewDeposit(amount);
        vaultSupplier2.depositVault(daiSupplyVault, amount);
        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier2)), preview2, "after");
    }

    function testPreviewWithdraw() public {
        uint256 amount = 1e5 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount * 2);
        vaultSupplier2.depositVault(daiSupplyVault, amount * 2);

        uint256 balanceBefore1 = daiSupplyVault.balanceOf(address(vaultSupplier1));
        uint256 balanceBefore2 = daiSupplyVault.balanceOf(address(vaultSupplier2));

        vm.warp(block.timestamp + 1000);

        // This should test that using the lens' predicted indexes is the correct amount to use.
        uint256 preview1 = daiSupplyVault.previewWithdraw(amount);
        vaultSupplier1.withdrawVault(daiSupplyVault, amount);
        assertEq(preview1, balanceBefore1 - daiSupplyVault.balanceOf(address(vaultSupplier1)));

        // The withdraw interacts with Morpho which updates the indexes,
        // so this should test that the lens predicted index does not differ from Morpho's actual index
        uint256 preview2 = daiSupplyVault.previewWithdraw(amount);
        vaultSupplier2.withdrawVault(daiSupplyVault, amount);
        assertEq(preview2, balanceBefore2 - daiSupplyVault.balanceOf(address(vaultSupplier2)));
    }

    function testPreviewRedeem() public {
        uint256 amount = 1e5 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount * 2);
        vaultSupplier2.depositVault(daiSupplyVault, amount * 2);

        uint256 balanceBefore1 = ERC20(dai).balanceOf(address(vaultSupplier1));
        uint256 balanceBefore2 = ERC20(dai).balanceOf(address(vaultSupplier2));

        vm.warp(block.timestamp + 1000);

        // This should test that using the lens' predicted indexes is the correct amount to use.
        uint256 preview1 = daiSupplyVault.previewRedeem(amount);
        vaultSupplier1.redeemVault(daiSupplyVault, amount);
        assertEq(balanceBefore1 + preview1, ERC20(dai).balanceOf(address(vaultSupplier1)));

        // The redeem interacts with Morpho which updates the indexes,
        // so this should test that the lens predicted index does not differ from Morpho's actual index
        uint256 preview2 = daiSupplyVault.previewRedeem(amount);
        vaultSupplier2.redeemVault(daiSupplyVault, amount);
        assertEq(balanceBefore2 + preview2, ERC20(dai).balanceOf(address(vaultSupplier2)));
    }
}
