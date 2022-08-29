// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyVault is TestSetupVaults {
    using WadRayMath for uint256;

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

    function testShouldClaimRewards() public {
        uint256 amount = 10_000 ether;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 20 days);

        uint256 balanceBefore = vaultSupplier1.balanceOf(stkAave);

        uint256 claimedAmount = daiSupplyVault.claimRewards(address(vaultSupplier1));

        uint256 balanceAfter = vaultSupplier1.balanceOf(stkAave);

        assertGt(claimedAmount, 0);
        assertApproxEqAbs(
            ERC20(stkAave).balanceOf(address(daiSupplyVault)),
            0,
            1e4,
            "non zero rewardToken balance on vault"
        );
        assertEq(balanceAfter, balanceBefore + claimedAmount, "unexpected rewardToken balance");
    }

    function testShouldClaimTwiceRewardsWhenDepositedForSameAmountAndTwiceDuration() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier2.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 claimedAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));

        uint256 claimedAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));

        assertApproxEqAbs(
            expectedTotalRewardsAmount,
            claimedAmount1 + claimedAmount2,
            1e5,
            "unexpected total rewards amount"
        );
        assertLt(claimedAmount1 + claimedAmount2, expectedTotalRewardsAmount);
        assertApproxEqAbs(claimedAmount1, 2 * claimedAmount2, 1e15, "unexpected rewards amount"); // not exact because of rewardTokenounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedAtSameTime() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);
        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        uint256 claimedAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));

        uint256 claimedAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));

        assertApproxEqAbs(
            expectedTotalRewardsAmount,
            claimedAmount1 + claimedAmount2,
            1e5,
            "unexpected total rewards amount"
        );
        assertGe(expectedTotalRewardsAmount, claimedAmount1 + claimedAmount2);
        assertApproxEqAbs(claimedAmount1, claimedAmount2, 1e15, "unexpected rewards amount"); // not exact because of rewardTokenounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration1() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 claimedAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));

        uint256 claimedAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));

        assertApproxEqAbs(
            expectedTotalRewardsAmount,
            claimedAmount1 + claimedAmount2,
            1e5,
            "unexpected total rewards amount"
        );
        assertGt(expectedTotalRewardsAmount, claimedAmount1 + claimedAmount2);
        assertApproxEqAbs(claimedAmount1, claimedAmount2, 1e15, "unexpected rewards amount"); // not exact because of rewardTokenounded interests
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration2() public {
        uint256 amount = 10_000 ether;
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = aDai;

        uint256 shares1 = vaultSupplier1.depositVault(daiSupplyVault, amount);

        vm.warp(block.timestamp + 10 days);

        uint256 expectedTotalRewardsAmount = rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 shares2 = vaultSupplier2.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        uint256 shares3 = vaultSupplier3.depositVault(daiSupplyVault, amount);
        vaultSupplier1.redeemVault(daiSupplyVault, shares1 / 2);
        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier2.redeemVault(daiSupplyVault, shares2 / 2);
        vaultSupplier3.redeemVault(daiSupplyVault, shares3 / 2);

        vm.warp(block.timestamp + 10 days);

        expectedTotalRewardsAmount += rewardsManager.getUserUnclaimedRewards(
            poolTokens,
            address(daiSupplyVault)
        );

        vaultSupplier3.redeemVault(daiSupplyVault, shares3 / 2);

        uint256 claimedAmount1 = daiSupplyVault.claimRewards(address(vaultSupplier1));

        uint256 claimedAmount2 = daiSupplyVault.claimRewards(address(vaultSupplier2));

        uint256 claimedAmount3 = daiSupplyVault.claimRewards(address(vaultSupplier3));

        assertApproxEqAbs(
            expectedTotalRewardsAmount,
            claimedAmount1 + claimedAmount2 + claimedAmount3,
            1e5,
            "unexpected total rewards amount"
        );
        assertGe(expectedTotalRewardsAmount, claimedAmount1 + claimedAmount2 + claimedAmount3);
        assertApproxEqAbs(
            ERC20(aave).balanceOf(address(daiSupplyVault)),
            0,
            1e15,
            "non zero rewardToken balance on vault"
        );
        assertApproxEqAbs(claimedAmount1, claimedAmount2, 1e15, "unexpected rewards amount 1-2"); // not exact because of rewardTokenounded interests
        assertApproxEqAbs(claimedAmount2, claimedAmount3, 1e15, "unexpected rewards amount 2-3"); // not exact because of rewardTokenounded interests
    }
}
