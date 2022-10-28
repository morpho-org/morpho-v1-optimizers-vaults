// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyVault is TestSetupVaults {
    using CompoundMath for uint256;

    function testCorrectInitialisation() public {
        assertEq(daiSupplyVault.owner(), address(this));
        assertEq(daiSupplyVault.name(), "MorphoCompoundDAI");
        assertEq(daiSupplyVault.symbol(), "mcDAI");
        assertEq(daiSupplyVault.poolToken(), cDai);
        assertEq(daiSupplyVault.asset(), dai);
        assertEq(daiSupplyVault.decimals(), 18);
    }

    function testCorrectInitialisationUsdc() public {
        assertEq(usdcSupplyVault.owner(), address(this));
        assertEq(usdcSupplyVault.name(), "MorphoCompoundUSDC");
        assertEq(usdcSupplyVault.symbol(), "mcUSDC");
        assertEq(usdcSupplyVault.poolToken(), cUsdc);
        assertEq(usdcSupplyVault.asset(), usdc);
        assertEq(usdcSupplyVault.decimals(), 18);
    }

    function testShouldDepositAmount() public {
        uint256 amount = 10_000 ether;

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
        uint256 amount = 10_000 ether;

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

        vaultSupplier1.depositVault(usdcSupplyVault, amount);
        vaultSupplier1.withdrawVault(usdcSupplyVault, expectedOnPool.mul(poolSupplyIndex));

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            cUsdc,
            address(usdcSupplyVault)
        );

        assertApproxEqAbs(
            usdcSupplyVault.balanceOf(address(vaultSupplier1)),
            0,
            10,
            "mcUSDC balance not zero"
        );
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllShares() public {
        uint256 amount = 10_000 ether;

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

        vm.roll(block.number + 1_000);

        uint256 balanceBefore = vaultSupplier1.balanceOf(comp);

        uint256 rewardsAmount = daiSupplyVault.claimRewards(address(vaultSupplier1));

        uint256 balanceAfter = vaultSupplier1.balanceOf(comp);

        assertGt(rewardsAmount, 0);
        assertApproxEqAbs(
            ERC20(comp).balanceOf(address(daiSupplyVault)),
            0,
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
            1e5,
            "unexpected total rewards amount"
        );
        assertLt(rewardsAmount1 + rewardsAmount2, expectedTotalRewardsAmount);
        assertApproxEqAbs(rewardsAmount1, 2 * rewardsAmount2, 1e9, "unexpected rewards amount"); // not exact because of compounded interests
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
            1e5,
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
            1e5,
            "unexpected total rewards amount"
        );
        assertLt(rewardsAmount1 + rewardsAmount2 + rewardsAmount3, expectedTotalRewardsAmount);
        assertApproxEqAbs(
            ERC20(comp).balanceOf(address(daiSupplyVault)),
            0,
            1e5,
            "non zero comp balance on vault"
        );
        assertApproxEqAbs(rewardsAmount1, rewardsAmount2, 1e9, "unexpected rewards amount 1-2"); // not exact because of compounded interests
        assertApproxEqAbs(rewardsAmount2, rewardsAmount3, 1e9, "unexpected rewards amount 2-3"); // not exact because of compounded interests
    }

    function testNotOwnerShouldNotSetRecipient() public {
        vm.prank(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyVault.setRewardsRecipient(address(1));
    }

    function testOwnerShouldSetRecipient() public {
        daiSupplyVault.setRewardsRecipient(address(1));
        assertEq(daiSupplyVault.recipient(), address(1));
    }

    function testCannotSetRecipientToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyVaultBase.ZeroAddress.selector));
        daiSupplyVault.setRewardsRecipient(address(0));
    }

    function testCannotTransferRewardsToNotSetZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyVaultBase.ZeroAddress.selector));
        daiSupplyVault.transferRewards();
    }

    function testEverybodyCanTransferRewardsToRecipient(uint256 _amount) public {
        vm.assume(_amount > 0);

        daiSupplyVault.setRewardsRecipient(address(1));
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(1)), 0);

        deal(MORPHO_TOKEN, address(daiSupplyVault), _amount);
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(daiSupplyVault)), _amount);

        // Allow the vault to transfer rewards.
        vm.prank(MORPHO_DAO);
        IRolesAuthority(MORPHO_TOKEN).setUserRole(address(daiSupplyVault), 0, true);

        vm.startPrank(address(2));
        daiSupplyVault.transferRewards();

        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(daiSupplyVault)), 0);
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(1)), _amount);
    }

    function testAccrueRewardsToCorrectUser() public {
        uint256 amount = 1e6 ether;

        ERC20(dai).approve(address(daiSupplyVault), type(uint256).max);
        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 1000);

        vaultSupplier1.redeemVault(
            daiSupplyVault,
            daiSupplyVault.balanceOf(address(supplier1)),
            address(supplier2),
            address(supplier1)
        );

        // Balance of supplier1 is expected to be 0.
        assertEq(daiSupplyVault.balanceOf(address(supplier1)), 0);

        // supplier1 must have some rewards to claim.
        (, uint256 unclaimed) = daiSupplyVault.userRewards(address(supplier1));
        assertGt(unclaimed, 0);
    }
}
