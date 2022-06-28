// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyVault is TestSetupVaults {
    using CompoundMath for uint256;

    function testShouldDepositAmount() public {
        uint256 amount = 10000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cDai);
        uint256 poolSupplyIndex = ICToken(cDai).exchangeRateCurrent();

        assertGt(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcDAI balance is zero");
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

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.withdrawVault(daiSupplyVault, expectedOnPool.mul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cDai,
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

        uint256 poolSupplyIndex = ICToken(cUsdc).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        vaultSupplier1.depositVault(usdcSupplyVault, amount);
        vaultSupplier1.withdrawVault(usdcSupplyVault, expectedOnPool.mul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            address(cUsdc),
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
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares); // cannot withdraw amount because of Compound rounding errors

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyVault)
        );

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcDAI balance not zero");
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldNotWithdrawWhenNotDeposited() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vaultSupplier2.redeemVault(daiSupplyVault, shares);
    }

    function testShouldNotWithdrawOnBehalfIfNotAllowed() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC20: insufficient allowance");
        vaultSupplier1.redeemVault(daiSupplyVault, shares, address(vaultSupplier2));
    }

    function testShouldWithdrawOnBehalfIfAllowed() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vaultSupplier1.approve(address(mcDai), address(vaultSupplier2), shares);
        vaultSupplier2.redeemVault(daiSupplyVault, shares, address(vaultSupplier1));
    }

    function testShouldNotDepositZeroAmount() public {
        vm.expectRevert(abi.encodeWithSignature("ShareIsZero()"));
        vaultSupplier1.depositVault(daiSupplyVault, 0);
    }

    function testShouldNotMintZeroShare() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        vaultSupplier1.mintVault(daiSupplyVault, 0);
    }

    function testShouldNotWithdrawGreaterAmount() public {
        uint256 amount = 10000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vaultSupplier1.withdrawVault(daiSupplyVault, amount * 2);
    }

    function testShouldNotRedeemMoreShares() public {
        uint256 amount = 10000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vaultSupplier1.redeemVault(daiSupplyVault, shares + 1);
    }

    function testShouldClaimRewards() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 1_000);

        uint256 balanceBefore = vaultSupplier1.balanceOf(comp);

        uint256 rewardsAmount = daiSupplyVault.claimRewards(address(vaultSupplier1));

        uint256 balanceAfter = vaultSupplier1.balanceOf(comp);

        assertGt(rewardsAmount, 0);
        assertEq(
            ERC20(comp).balanceOf(address(daiSupplyVault)),
            0,
            "non zero comp balance on vault"
        );
        assertEq(balanceAfter, balanceBefore + rewardsAmount, "unexpected comp balance");
    }

    function testShouldClaimTwiceRewardsWhenDepositedForSameAmountAndTwiceDuration() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        vaultSupplier2.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        address[] memory poolTokenAddresses = new address[](1);
        poolTokenAddresses[0] = cDai;
        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokenAddresses,
            address(daiSupplyVault)
        );

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));

        assertApproxEqAbs(
            rewardsAmount1 + rewardsAmount2,
            expectedTotalRewardsAmount,
            1e8,
            "unexpected total rewards amount"
        );
        assertLt(rewardsAmount1 + rewardsAmount2, expectedTotalRewardsAmount);
        assertApproxEqAbs(rewardsAmount1, 2 * rewardsAmount2, 1e9, "unexpected rewards amount"); // not exact because of compounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration1() public {
        uint256 amount = 10_000 ether;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 1000_000);

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.roll(block.number + 1000_000);

        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.roll(block.number + 1000_000);

        address[] memory poolTokenAddresses = new address[](1);
        poolTokenAddresses[0] = cDai;
        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokenAddresses,
            address(daiSupplyVault)
        );

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        console.log("3 * rewardsAmount1", 3 * rewardsAmount1);
        console.log("expectedTotalRewardsAmount", expectedTotalRewardsAmount);
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));

        assertEq(
            rewardsAmount1 + rewardsAmount2,
            expectedTotalRewardsAmount,
            "unexpected total rewards amount"
        );
        assertEq(rewardsAmount1, rewardsAmount2, "unexpected rewards amount");
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration2() public {
        uint256 amount = 10_000 ether;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 1000_000);

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.roll(block.number + 1000_000);

        uint256 shares3 = vaultSupplier3.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.roll(block.number + 1000_000);

        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);
        vaultSupplier3.redeemVault(daiSupplyVault, shares3 / 2);

        vm.roll(block.number + 1000_000);

        vaultSupplier3.redeemVault(daiSupplyVault, shares3 / 2);

        address[] memory poolTokenAddresses = new address[](1);
        poolTokenAddresses[0] = cDai;
        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokenAddresses,
            address(daiSupplyVault)
        );

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        console.log("3 * rewardsAmount1", 3 * rewardsAmount1);
        console.log("expectedTotalRewardsAmount", expectedTotalRewardsAmount);
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));
        uint256 rewardsAmount3 = daiSupplyVault.claimRewards(address(vaultSupplier3));

        assertEq(
            rewardsAmount1 + rewardsAmount2 + rewardsAmount3,
            expectedTotalRewardsAmount,
            "unexpected total rewards amount"
        );
        assertEq(rewardsAmount1, rewardsAmount2, "unexpected rewards amount 1-2");
        assertEq(rewardsAmount2, rewardsAmount3, "unexpected rewards amount 2-3");
    }

    function testShouldUpdateSameIndexAsCompound() public {
        uint256 amount = 10_000 ether;

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 5_000);

        vaultSupplier1.redeemVault(daiSupplyVault, shares);

        vaultSupplier1.compoundSupply(cDai, amount);

        vm.roll(block.number + 5_000);

        uint256 userRewardsIndex = daiSupplyVault.compRewardsIndex(address(vaultSupplier1));
        IComptroller.CompMarketState memory compoundState = comptroller.compSupplyState(cDai);

        assertEq(userRewardsIndex, compoundState.index);
    }
}
