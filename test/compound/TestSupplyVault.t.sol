// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestSupplyVault is TestSetup {
    using CompoundMath for uint256;

    function testShouldDepositAmount() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        supplier1.deposit(daiSupplyVault, amount);

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cDai),
            address(daiSupplyVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(address(cDai));
        uint256 poolSupplyIndex = cDai.exchangeRateCurrent();

        assertGt(daiSupplyVault.balanceOf(address(supplier1)), 0, "mcDAI balance is zero");
        assertApproxEqAbs(
            supplyBalance.inP2P.mul(p2pSupplyIndex) + supplyBalance.onPool.mul(poolSupplyIndex),
            amount.div(poolSupplyIndex).mul(poolSupplyIndex),
            1e10
        );
    }

    function testShouldWithdrawAllAmount() public {
        uint256 amount = 10000 ether;

        uint256 poolSupplyIndex = cDai.exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        supplier1.approve(dai, address(daiSupplyVault), amount);
        supplier1.deposit(daiSupplyVault, amount);
        supplier1.withdraw(daiSupplyVault, expectedOnPool.mul(poolSupplyIndex));

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cDai),
            address(daiSupplyVault)
        );

        assertApproxEqAbs(
            daiSupplyVault.balanceOf(address(supplier1)),
            0,
            1e3,
            "mcDAI balance not zero"
        );
        assertEq(supplyBalance.onPool, 0, "onPool amount not zero");
        assertEq(supplyBalance.inP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllUsdcAmount() public {
        uint256 amount = 1e9;

        uint256 poolSupplyIndex = ICToken(cUsdc).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        supplier1.approve(usdc, address(usdcSupplyVault), amount);
        supplier1.deposit(usdcSupplyVault, amount);
        supplier1.withdraw(usdcSupplyVault, expectedOnPool.mul(poolSupplyIndex));

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cUsdc),
            address(usdcSupplyVault)
        );

        assertApproxEqAbs(
            usdcSupplyVault.balanceOf(address(supplier1)),
            0,
            10,
            "mcUSDT balance not zero"
        );
        assertEq(supplyBalance.onPool, 0, "onPool amount not zero");
        assertEq(supplyBalance.inP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllShares() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyVault, amount);
        supplier1.redeem(daiSupplyVault, shares); // cannot withdraw amount because of Compound rounding errors

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cDai),
            address(daiSupplyVault)
        );

        assertEq(daiSupplyVault.balanceOf(address(supplier1)), 0, "mcDAI balance not zero");
        assertEq(supplyBalance.onPool, 0, "onPool amount not zero");
        assertEq(supplyBalance.inP2P, 0, "inP2P amount not zero");
    }

    function testShouldNotWithdrawWhenNotDeposited() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        supplier2.redeem(daiSupplyVault, shares);
    }

    function testShouldNotWithdrawOnBehalfIfNotAllowed() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyVault, amount);

        vm.expectRevert("ERC20: insufficient allowance");
        supplier1.redeem(daiSupplyVault, shares, address(supplier2));
    }

    function testShouldWithdrawOnBehalfIfAllowed() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyVault, amount);

        supplier1.approve(mcDai, address(supplier2), shares);
        supplier2.redeem(daiSupplyVault, shares, address(supplier1));
    }

    function testShouldNotDepositZeroAmount() public {
        vm.expectRevert(abi.encodeWithSignature("ShareIsZero()"));
        supplier1.deposit(daiSupplyVault, 0);
    }

    function testShouldNotMintZeroShare() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        supplier1.mint(daiSupplyVault, 0);
    }

    function testShouldNotWithdrawGreaterAmount() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        supplier1.deposit(daiSupplyVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        supplier1.withdraw(daiSupplyVault, amount * 2);
    }

    function testShouldNotRedeemMoreShares() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        supplier1.redeem(daiSupplyVault, shares + 1);
    }

    function testShouldClaimRewards() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        supplier1.deposit(daiSupplyVault, amount);

        vm.roll(block.number + 1_000);

        uint256 balanceBefore = supplier1.balanceOf(comp);

        uint256 rewardsAmount = daiSupplyVault.claimRewards(address(supplier1));

        uint256 balanceAfter = supplier1.balanceOf(comp);

        assertGt(rewardsAmount, 0);
        assertEq(comp.balanceOf(address(daiSupplyVault)), 0, "non zero comp balance on vault");
        assertEq(balanceAfter, balanceBefore + rewardsAmount, "unexpected comp balance");
    }

    function testShouldClaimTwiceRewardsWhenDepositedForSameAmountAndTwiceDuration() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        supplier1.deposit(daiSupplyVault, amount);

        vm.roll(block.number + 1_000);

        supplier2.approve(dai, address(daiSupplyVault), amount);
        supplier2.deposit(daiSupplyVault, amount);

        vm.roll(block.number + 1_000);

        address[] memory poolTokenAddresses = new address[](1);
        poolTokenAddresses[0] = address(cDai);
        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokenAddresses,
            address(daiSupplyVault)
        );

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(supplier1));
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(supplier2));

        assertEq(
            rewardsAmount1 + rewardsAmount2,
            expectedTotalRewardsAmount,
            "unexpected total rewards amount"
        );
        assertEq(rewardsAmount1, 2 * rewardsAmount2, "unexpected rewards amount");
    }

    function testShouldClaimSameRewardsWhenDepositedForSameAmountAndDuration() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        uint256 shares1 = supplier1.deposit(daiSupplyVault, amount);

        vm.roll(block.number + 1_000);

        supplier2.approve(dai, address(daiSupplyVault), amount);
        uint256 shares2 = supplier2.deposit(daiSupplyVault, amount);
        supplier1.redeem(daiSupplyVault, shares1 / 2);

        vm.roll(block.number + 1_000);

        supplier1.redeem(daiSupplyVault, shares1 / 2);
        supplier2.redeem(daiSupplyVault, shares2 / 2);

        vm.roll(block.number + 1_000);

        address[] memory poolTokenAddresses = new address[](1);
        poolTokenAddresses[0] = address(cDai);
        uint256 expectedTotalRewardsAmount = lens.getUserUnclaimedRewards(
            poolTokenAddresses,
            address(daiSupplyVault)
        );

        uint256 rewardsAmount1 = daiSupplyVault.claimRewards(address(supplier1));
        uint256 rewardsAmount2 = daiSupplyVault.claimRewards(address(supplier2));

        assertEq(
            rewardsAmount1 + rewardsAmount2,
            expectedTotalRewardsAmount,
            "unexpected total rewards amount"
        );
        assertEq(rewardsAmount1, rewardsAmount2, "unexpected rewards amount");
    }

    function testShouldUpdateSameIndexAsCompound() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, address(daiSupplyVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyVault, amount);

        vm.roll(block.number + 5_000);

        supplier1.redeem(daiSupplyVault, shares);

        supplier1.compoundSupply(cDai, amount);

        vm.roll(block.number + 5_000);

        uint256 userRewardsIndex = daiSupplyVault.compRewardsIndex(address(supplier1));
        IComptroller.CompMarketState memory compoundState = comptroller.compSupplyState(
            address(cDai)
        );

        assertEq(userRewardsIndex, compoundState.index);
    }
}
