// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "../setup/TestSetupVaultsLive.sol";

contract TestSupplyVaultLive is TestSetupVaultsLive {
    using CompoundMath for uint256;

    function testLog() public view {
        console2.log(string(abi.encodePacked("Test at block ", Strings.toString(block.number))));
    }

    function testShouldDepositAmount() public {
        uint256 amount = 10_000 ether;
        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndexBefore = morpho.p2pSupplyIndex(cDai);
        uint256 poolSupplyIndexBefore = ICToken(cDai).exchangeRateCurrent();

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndexAfter = morpho.p2pSupplyIndex(cDai);
        uint256 poolSupplyIndexAfter = ICToken(cDai).exchangeRateCurrent();

        assertGt(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcDAI balance is zero");
        assertApproxEqAbs(
            balanceInP2PAfter.mul(p2pSupplyIndexAfter) +
                balanceOnPoolAfter.mul(poolSupplyIndexAfter),
            amount +
                balanceInP2PBefore.mul(p2pSupplyIndexBefore) +
                balanceOnPoolBefore.mul(poolSupplyIndexBefore),
            1e10
        );
    }

    function testShouldWithdrawAllAmount() public {
        uint256 amount = 10_000 ether;

        uint256 poolSupplyIndex = ICToken(cDai).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);
        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cDai);

        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyVault)
        );

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.withdrawVault(daiSupplyVault, expectedOnPool.mul(poolSupplyIndex));

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyVault)
        );

        assertApproxEqAbs(
            daiSupplyVault.balanceOf(address(vaultSupplier1)),
            0,
            5e3,
            "mcDAI balance not zero"
        );
        assertApproxEqAbs(
            balanceInP2PAfter.mul(p2pSupplyIndex) + balanceOnPoolAfter.mul(poolSupplyIndex),
            balanceInP2PBefore.mul(p2pSupplyIndex) + balanceOnPoolBefore.mul(poolSupplyIndex),
            1e10
        );
    }

    function testShouldWithdrawAllUsdcAmount() public {
        uint256 amount = 1e9;

        uint256 poolSupplyIndex = ICToken(cUsdc).exchangeRateCurrent();
        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cUsdc);

        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cUsdc,
            address(usdcSupplyVault)
        );

        vaultSupplier1.depositVault(usdcSupplyVault, amount);
        vaultSupplier1.redeemVault(
            usdcSupplyVault,
            usdcSupplyVault.maxRedeem(address(vaultSupplier1))
        );

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cUsdc,
            address(usdcSupplyVault)
        );

        assertApproxEqAbs(
            usdcSupplyVault.balanceOf(address(vaultSupplier1)),
            0,
            10,
            "mcUSDC balance not zero"
        );
        assertApproxEqAbs(
            balanceInP2PAfter.mul(p2pSupplyIndex) + balanceOnPoolAfter.mul(poolSupplyIndex),
            balanceInP2PBefore.mul(p2pSupplyIndex) + balanceOnPoolBefore.mul(poolSupplyIndex),
            1e10
        );
    }

    function testShouldWithdrawAllShares() public {
        uint256 amount = 10_000 ether;
        uint256 poolSupplyIndex = ICToken(cDai).exchangeRateCurrent();

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cDai);

        (uint256 balanceInP2PBefore, uint256 balanceOnPoolBefore) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyVault)
        );

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares); // cannot withdraw amount because of Compound rounding errors

        (uint256 balanceInP2PAfter, uint256 balanceOnPoolAfter) = morpho.supplyBalanceInOf(
            cDai,
            address(daiSupplyVault)
        );

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcDAI balance not zero");
        assertApproxEqAbs(
            balanceInP2PAfter.mul(p2pSupplyIndex) + balanceOnPoolAfter.mul(poolSupplyIndex),
            balanceInP2PBefore.mul(p2pSupplyIndex) + balanceOnPoolBefore.mul(poolSupplyIndex),
            1e10
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

        vaultSupplier1.approve(address(mcDai), address(vaultSupplier2), shares);
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

    function testShouldClaimRewards() public {
        uint256 amount = 10_000 ether;
        vaultSupplier1.depositVault(daiSupplyVault, amount);

        // Claim to accurately track rewards for 1000 blocks
        daiSupplyVault.claimRewards(address(vaultSupplier1));
        uint256 balanceOfVaultBefore = ERC20(comp).balanceOf(address(daiSupplyVault));

        vm.roll(block.number + 1_000);

        uint256 userBalance = daiSupplyVault.balanceOf(address(vaultSupplier1));
        uint256 totalSupply = daiSupplyVault.totalSupply();

        uint256 balanceBefore = vaultSupplier1.balanceOf(comp);

        uint256 rewardsAmount = daiSupplyVault.claimRewards(address(vaultSupplier1));

        uint256 balanceAfter = vaultSupplier1.balanceOf(comp);

        assertGt(rewardsAmount, 0);
        assertApproxEqAbs(
            ERC20(comp).balanceOf(address(daiSupplyVault)),
            (rewardsAmount * (totalSupply - userBalance)) / userBalance + balanceOfVaultBefore,
            1e4,
            "non zero comp balance on vault"
        );
        assertEq(balanceAfter, balanceBefore + rewardsAmount, "unexpected comp balance");
    }

    function testShouldClaimTwiceRewardsWhenDepositedForSameAmountAndTwiceDuration() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = cDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier2.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));

        assertApproxEqAbs(
            rewardsAmount1 + rewardsAmount2,
            expectedTotalRewardsAmount,
            expectedTotalRewardsAmount / 1e5,
            "unexpected total rewards amount"
        );
        assertLt(rewardsAmount1 + rewardsAmount2, expectedTotalRewardsAmount);
        assertApproxEqAbs(rewardsAmount1, 2 * rewardsAmount2, 5e9, "unexpected rewards amount"); // not exact because of compounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration1() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = cDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));

        assertApproxEqAbs(
            rewardsAmount1 + rewardsAmount2,
            expectedTotalRewardsAmount,
            expectedTotalRewardsAmount / 1e5,
            "unexpected total rewards amount"
        );
        assertLt(rewardsAmount1 + rewardsAmount2, expectedTotalRewardsAmount);
        assertApproxEqAbs(rewardsAmount1, rewardsAmount2, 1e8, "unexpected rewards amount"); // not exact because of compounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration2() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = cDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 shares3 = vaultSupplier3.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);
        vaultSupplier3.redeemVault(daiSupplyVault, shares3 / 2);

        vm.roll(block.number + 100);

        expectedTotalRewardsAmount += lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier3.redeemVault(daiSupplyVault, shares3 / 2);

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));
        uint256 rewardsAmount3 = daiSupplyVault.claimRewards(address(vaultSupplier3));

        assertApproxEqAbs(
            rewardsAmount1 + rewardsAmount2 + rewardsAmount3,
            expectedTotalRewardsAmount,
            expectedTotalRewardsAmount / 1e5,
            "unexpected total rewards amount"
        );
        assertLt(rewardsAmount1 + rewardsAmount2 + rewardsAmount3, expectedTotalRewardsAmount);
        assertApproxEqAbs(rewardsAmount1, rewardsAmount2, 1e9, "unexpected rewards amount 1-2"); // not exact because of compounded interests
        assertApproxEqAbs(rewardsAmount2, rewardsAmount3, 1e9, "unexpected rewards amount 2-3"); // not exact because of compounded interests
    }
}
