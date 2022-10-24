// SPDX-License-Identifier: GNU AGPLv3
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

    function testNotOwnerShouldNotTransferTokens(uint256 _amount) public {
        vm.prank(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyVault.transferTokens($token, address(2), _amount);
    }

    function testOwnerShouldTransferTokens(
        address _to,
        uint256 _deal,
        uint256 _toTransfer
    ) public {
        vm.assume(_to != address(daiSupplyVault));
        _toTransfer = bound(_toTransfer, 0, _deal);
        deal($token, address(daiSupplyVault), _deal);

        vm.prank(daiSupplyVault.owner());
        daiSupplyVault.transferTokens($token, _to, _toTransfer);

        assertEq(token.balanceOf(address(daiSupplyVault)), _deal - _toTransfer);
        assertEq(token.balanceOf(_to), _toTransfer);
    }
}
