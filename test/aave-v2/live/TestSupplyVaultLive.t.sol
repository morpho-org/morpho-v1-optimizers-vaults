// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "../setup/TestSetupVaultsLive.sol";

contract TestSupplyVaultLive is TestSetupVaultsLive {
    using WadRayMath for uint256;

    function testLog() public view {
        console2.log(string(abi.encodePacked("Test at block ", Strings.toString(block.number))));
    }

    function testShouldDepositAmount() public {
        uint256 amount = 10_000 ether;

        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndexBefore = morpho.p2pSupplyIndex(aDai);
        uint256 poolSupplyIndexBefore = pool.getReserveNormalizedIncome(dai);

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndexAfter = morpho.p2pSupplyIndex(aDai);
        uint256 poolSupplyIndexAfter = pool.getReserveNormalizedIncome(dai);

        assertGt(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "maDAI balance is zero");
        assertApproxEqAbs(
            balanceInP2PAfter.rayMul(p2pSupplyIndexAfter) +
                balanceOnPoolAfter.rayMul(poolSupplyIndexAfter),
            amount +
                balanceInP2PBefore.rayMul(p2pSupplyIndexBefore) +
                balanceOnPoolBefore.rayMul(poolSupplyIndexBefore),
            1e10
        );
    }

    function testShouldWithdrawAllAmount() public {
        uint256 amount = 10_000 ether;

        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(aDai);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(dai);

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.withdrawVault(
            daiSupplyVault,
            daiSupplyVault.maxWithdraw(address(vaultSupplier1))
        );

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        assertApproxEqAbs(
            daiSupplyVault.balanceOf(address(vaultSupplier1)),
            0,
            1e3,
            "mcDAI balance not zero"
        );
        assertApproxEqAbs(
            balanceInP2PAfter.rayMul(p2pSupplyIndex) + balanceOnPoolAfter.rayMul(poolSupplyIndex),
            balanceInP2PBefore.rayMul(p2pSupplyIndex) + balanceOnPoolBefore.rayMul(poolSupplyIndex),
            1e10
        );
    }

    function testShouldWithdrawAllUsdcAmount() public {
        uint256 amount = 1e9;

        uint256 balanceBefore = ERC20(usdc).balanceOf(address(vaultSupplier1));

        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            aUsdc,
            address(usdcSupplyVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(aUsdc);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(usdc);

        vaultSupplier1.depositVault(usdcSupplyVault, amount);
        vaultSupplier1.withdrawVault(
            usdcSupplyVault,
            usdcSupplyVault.maxWithdraw(address(vaultSupplier1))
        );

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            address(aUsdc),
            address(usdcSupplyVault)
        );
        assertApproxEqAbs(
            usdcSupplyVault.balanceOf(address(vaultSupplier1)),
            0,
            usdcSupplyVault.totalSupply() / 1e5
        );

        assertApproxEqAbs(ERC20(usdc).balanceOf(address(vaultSupplier1)), balanceBefore, 1);

        assertApproxEqAbs(
            balanceInP2PAfter.rayMul(p2pSupplyIndex) + balanceOnPoolAfter.rayMul(poolSupplyIndex),
            balanceInP2PBefore.rayMul(p2pSupplyIndex) + balanceOnPoolBefore.rayMul(poolSupplyIndex),
            1e5
        );
    }

    function testShouldWithdrawAllShares() public {
        uint256 amount = 10_000 ether;

        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(aDai);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(dai);

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares); // cannot withdraw amount because of Compound rounding errors

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            aDai,
            address(daiSupplyVault)
        );

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcDAI balance not zero");
        assertApproxEqAbs(
            balanceInP2PAfter.rayMul(p2pSupplyIndex) + balanceOnPoolAfter.rayMul(poolSupplyIndex),
            balanceInP2PBefore.rayMul(p2pSupplyIndex) + balanceOnPoolBefore.rayMul(poolSupplyIndex),
            1e5
        );
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
}
