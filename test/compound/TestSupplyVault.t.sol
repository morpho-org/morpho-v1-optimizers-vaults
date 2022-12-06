// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

import "./setup/TestSetupVaults.sol";

contract TestSupplyVault is TestSetupVaults {
    using FixedPointMathLib for uint256;
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
            3e3,
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

    function testRewardsShouldAccrueWhenDepositingOnBehalf() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = cDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        // Should update the unclaimed amount
        vaultSupplier2.depositVault(daiSupplyVault, amount, address(vaultSupplier1));
        (, uint128 userReward1_1) = daiSupplyVault.userRewards(address(vaultSupplier1));

        vm.roll(block.number + 100);

        (uint128 index2, uint128 userReward2) = daiSupplyVault.userRewards(address(vaultSupplier2));
        uint256 userReward1_2 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        assertEq(index2, 0);
        assertEq(userReward2, 0);
        assertGt(uint256(userReward1_1), 0);
        assertApproxEqAbs(uint256(userReward1_1), expectedTotalRewardsAmount, 10000);
        assertApproxEqAbs(uint256(userReward1_1) * 3, userReward1_2, userReward1_2 / 1000);
    }

    function testRewardsShouldAccrueWhenMintingOnBehalf() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = cDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );
        morpho.updateP2PIndexes(cDai);

        // Should update the unclaimed amount
        vaultSupplier2.mintVault(
            daiSupplyVault,
            daiSupplyVault.previewMint(amount),
            address(vaultSupplier1)
        );
        (, uint128 userReward1_1) = daiSupplyVault.userRewards(address(vaultSupplier1));

        vm.roll(block.number + 100);

        (uint128 index2, uint128 userReward2) = daiSupplyVault.userRewards(address(vaultSupplier2));
        uint256 userReward1_2 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        assertEq(index2, 0);
        assertEq(userReward2, 0);
        assertGt(uint256(userReward1_1), 0);
        assertApproxEqAbs(uint256(userReward1_1), expectedTotalRewardsAmount, 10000);
        assertApproxEqAbs(uint256(userReward1_1) * 3, userReward1_2, userReward1_2 / 1000);
    }

    function testRewardsShouldAccrueWhenRedeemingToReceiver() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = cDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );
        morpho.updateP2PIndexes(cDai);

        // Should update the unclaimed amount
        vaultSupplier1.redeemVault(
            daiSupplyVault,
            daiSupplyVault.balanceOf(address(vaultSupplier1)),
            address(vaultSupplier2),
            address(vaultSupplier1)
        );
        (, uint128 userReward1_1) = daiSupplyVault.userRewards(address(vaultSupplier1));

        vm.roll(block.number + 100);

        uint256 userReward1_2 = daiSupplyVault.claimRewards(address(vaultSupplier1));

        (uint128 index2, ) = daiSupplyVault.userRewards(address(vaultSupplier2));
        uint256 userReward2 = daiSupplyVault.claimRewards(address(vaultSupplier2));
        assertEq(index2, 0);
        assertEq(userReward2, 0);
        assertGt(uint256(userReward1_1), 0);
        assertApproxEqAbs(uint256(userReward1_1), expectedTotalRewardsAmount, 10000);
        assertApproxEqAbs(uint256(userReward1_1), userReward1_2, 1);
    }

    function testRewardsShouldAccrueWhenWithdrawingToReceiver() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = cDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);
        vm.roll(block.number + 100);

        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );
        morpho.updateP2PIndexes(cDai);

        // Should update the unclaimed amount
        vaultSupplier1.withdrawVault(
            daiSupplyVault,
            daiSupplyVault.maxWithdraw(address(vaultSupplier1)),
            address(vaultSupplier2),
            address(vaultSupplier1)
        );
        (, uint128 userReward1_1) = daiSupplyVault.userRewards(address(vaultSupplier1));

        vm.roll(block.number + 100);

        uint256 userReward1_2 = daiSupplyVault.claimRewards(address(vaultSupplier1));

        (uint128 index2, ) = daiSupplyVault.userRewards(address(vaultSupplier2));
        uint256 userReward2 = daiSupplyVault.claimRewards(address(vaultSupplier2));
        assertEq(index2, 0);
        assertEq(userReward2, 0);
        assertGt(uint256(userReward1_1), 0);
        assertApproxEqAbs(uint256(userReward1_1), expectedTotalRewardsAmount, 10000);
        assertApproxEqAbs(uint256(userReward1_1), userReward1_2, 1);
    }

    // TODO: fix this test by using updated indexes in previewMint
    // function testShouldMintCorrectAmountWhenMorphoPoolIndexesOutdated() public {
    //     uint256 amount = 10_000 ether;

    //     vaultSupplier1.depositVault(daiSupplyVault, amount);

    //     vm.roll(block.number + 100_000);
    //     vm.warp(block.timestamp + 1_000_000);

    //     uint256 assets = vaultSupplier2.mintVault(daiSupplyVault, amount);
    //     uint256 shares = vaultSupplier2.withdrawVault(daiSupplyVault, assets);

    //     assertEq(shares, amount, "unexpected redeemed shares");
    // }

    function testShouldDepositCorrectAmountWhenMorphoPoolIndexesOutdated() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100_000);
        vm.warp(block.timestamp + 1_000_000);

        uint256 shares = vaultSupplier2.depositVault(daiSupplyVault, amount);
        uint256 assets = vaultSupplier2.redeemVault(daiSupplyVault, shares);

        assertApproxEqAbs(assets, amount, 1e8, "unexpected withdrawn assets");
    }

    function testShouldRedeemAllAmountWhenMorphoPoolIndexesOutdated() public {
        uint256 amount = 10_000 ether;

        uint256 expectedOnPool = amount.div(ICToken(cDai).exchangeRateCurrent());

        uint256 shares = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100_000);
        vm.warp(block.timestamp + 1_000_000);

        uint256 assets = vaultSupplier1.redeemVault(daiSupplyVault, shares);

        assertApproxEqAbs(
            assets,
            expectedOnPool.mul(ICToken(cDai).exchangeRateCurrent()),
            1e4,
            "unexpected withdrawn assets"
        );
    }

    function testShouldWithdrawAllAmountWhenMorphoPoolIndexesOutdated() public {
        uint256 amount = 10_000 ether;

        uint256 expectedOnPool = amount.div(ICToken(cDai).exchangeRateCurrent());

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 100_000);

        vaultSupplier1.withdrawVault(
            daiSupplyVault,
            expectedOnPool.mul(ICToken(cDai).exchangeRateCurrent())
        );

        (uint256 balanceInP2P, uint256 balanceOnPool) = morpho.supplyBalanceInOf(
            address(cUsdc),
            address(daiSupplyVault)
        );

        assertEq(daiSupplyVault.balanceOf(address(vaultSupplier1)), 0, "mcUSDT balance not zero");
        assertEq(balanceOnPool, 0, "onPool amount not zero");
        assertEq(balanceInP2P, 0, "inP2P amount not zero");
    }

    function testTransfer() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        uint256 balance = daiSupplyVault.balanceOf(address(supplier1));
        vm.prank(address(supplier1));
        daiSupplyVault.transfer(address(supplier2), balance);

        assertEq(daiSupplyVault.balanceOf(address(supplier1)), 0);
        assertEq(daiSupplyVault.balanceOf(address(supplier2)), balance);
    }

    function testTransferFrom() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        uint256 balance = daiSupplyVault.balanceOf(address(supplier1));
        vm.prank(address(supplier1));
        daiSupplyVault.approve(address(supplier3), balance);

        vm.prank(address(supplier3));
        daiSupplyVault.transferFrom(address(supplier1), address(supplier2), balance);

        assertEq(daiSupplyVault.balanceOf(address(supplier1)), 0);
        assertEq(daiSupplyVault.balanceOf(address(supplier2)), balance);
    }

    function testTransferAccrueRewards() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 1000);

        uint256 balance = daiSupplyVault.balanceOf(address(supplier1));
        vm.prank(address(supplier1));
        daiSupplyVault.transfer(address(supplier2), balance);

        uint256 expectedIndex = ERC20(comp).balanceOf(address(daiSupplyVault)).divWadDown(
            daiSupplyVault.totalSupply()
        );
        uint256 rewardsIndex = daiSupplyVault.rewardsIndex();
        assertEq(expectedIndex, rewardsIndex);

        (uint256 index1, uint256 unclaimed1) = daiSupplyVault.userRewards(address(supplier1));
        assertEq(index1, rewardsIndex);
        assertGt(unclaimed1, 0);

        (uint256 index2, uint256 unclaimed2) = daiSupplyVault.userRewards(address(supplier2));
        assertEq(index2, rewardsIndex);
        assertEq(unclaimed2, 0);

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));
        assertGt(rewardsAmount1, 0);
        assertEq(rewardsAmount2, 0);
    }

    function testTransferFromAccrueRewards() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 1000);

        uint256 balance = daiSupplyVault.balanceOf(address(supplier1));
        vm.prank(address(supplier1));
        daiSupplyVault.approve(address(supplier3), balance);

        vm.prank(address(supplier3));
        daiSupplyVault.transferFrom(address(supplier1), address(supplier2), balance);

        uint256 expectedIndex = ERC20(comp).balanceOf(address(daiSupplyVault)).divWadDown(
            daiSupplyVault.totalSupply()
        );
        uint256 rewardsIndex = daiSupplyVault.rewardsIndex();
        assertEq(rewardsIndex, expectedIndex);

        (uint256 index1, uint256 unclaimed1) = daiSupplyVault.userRewards(address(supplier1));
        assertEq(index1, rewardsIndex);
        assertGt(unclaimed1, 0);

        (uint256 index2, uint256 unclaimed2) = daiSupplyVault.userRewards(address(supplier2));
        assertEq(index2, rewardsIndex);
        assertEq(unclaimed2, 0);

        (uint256 index3, uint256 unclaimed3) = daiSupplyVault.userRewards(address(supplier3));
        assertEq(index3, 0);
        assertEq(unclaimed3, 0);

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));
        uint256 rewardsAmount3 = daiSupplyVault.claimRewards(address(vaultSupplier3));
        assertGt(rewardsAmount1, 0);
        assertEq(rewardsAmount2, 0);
        assertEq(rewardsAmount3, 0);
    }

    function testTransferAndClaimRewards() public {
        uint256 amount = 1e6 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 1000);

        vaultSupplier2.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + 1000);

        uint256 balance = daiSupplyVault.balanceOf(address(supplier1));
        vm.prank(address(supplier1));
        daiSupplyVault.transfer(address(supplier2), balance);

        vm.roll(block.number + 1000);

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));

        assertGt(rewardsAmount1, 0);
        assertApproxEqAbs(rewardsAmount1, (2 * rewardsAmount2) / 3, 1e15);
        // Why rewardsAmount1 is 2/3 of rewardsAmount2 can be explained as follows:
        // supplier1 first gets X rewards corresponding to amount over one period of time
        // supplier1 then and supplier2 get X rewards each (under the approximation that doubling the amount doubles the rewards)
        // supplier2 then gets 2 * X rewards
        // In the end, supplier1 got 2 * X rewards while supplier2 got 3 * X
    }

    function testPreviewMint() public {
        uint256 amount = 1e5 ether;

        uint256 balanceBefore1 = ERC20(dai).balanceOf(address(vaultSupplier1));
        uint256 balanceBefore2 = ERC20(dai).balanceOf(address(vaultSupplier2));

        vm.roll(block.number + 100);

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

        vm.roll(block.number + 100);

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

        vm.roll(block.number + 100);

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

        vm.roll(block.number + 100);

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
