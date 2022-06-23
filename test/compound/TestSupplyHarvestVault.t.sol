// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestSupplyHarvestVault is TestSetup {
    using CompoundMath for uint256;

    function testShouldDepositAmount() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        supplier1.deposit(daiSupplyHarvestVault, amount);

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cDai),
            address(daiSupplyHarvestVault)
        );

        uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(address(cEth));
        uint256 poolSupplyIndex = cDai.exchangeRateCurrent();

        assertGt(daiSupplyHarvestVault.balanceOf(address(supplier1)), 0, "mchDAI balance is zero");
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

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        supplier1.deposit(daiSupplyHarvestVault, amount);
        supplier1.withdraw(daiSupplyHarvestVault, expectedOnPool.mul(poolSupplyIndex));

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cDai),
            address(daiSupplyHarvestVault)
        );

        assertApproxEqAbs(
            daiSupplyHarvestVault.balanceOf(address(supplier1)),
            0,
            10,
            "mcDAI balance not zero"
        );
        assertEq(supplyBalance.onPool, 0, "onPool amount not zero");
        assertEq(supplyBalance.inP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllUsdcAmount() public {
        uint256 amount = 1e9;

        uint256 poolSupplyIndex = ICToken(cUsdc).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        supplier1.approve(usdc, address(usdcSupplyHarvestVault), amount);
        supplier1.deposit(usdcSupplyHarvestVault, amount);
        supplier1.withdraw(usdcSupplyHarvestVault, expectedOnPool.mul(poolSupplyIndex));

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cUsdc),
            address(usdcSupplyHarvestVault)
        );

        assertApproxEqAbs(
            usdcSupplyHarvestVault.balanceOf(address(supplier1)),
            0,
            10,
            "mcUSDT balance not zero"
        );
        assertEq(supplyBalance.onPool, 0, "onPool amount not zero");
        assertEq(supplyBalance.inP2P, 0, "inP2P amount not zero");
    }

    function testShouldWithdrawAllShares() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyHarvestVault, amount);
        supplier1.redeem(daiSupplyHarvestVault, shares); // cannot withdraw amount because of Compound rounding errors

        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(cDai),
            address(daiSupplyHarvestVault)
        );

        assertEq(daiSupplyHarvestVault.balanceOf(address(supplier1)), 0, "mcDAI balance not zero");
        assertEq(supplyBalance.onPool, 0, "onPool amount not zero");
        assertEq(supplyBalance.inP2P, 0, "inP2P amount not zero");
    }

    function testShouldNotWithdrawWhenNotDeposited() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        supplier2.redeem(daiSupplyHarvestVault, shares);
    }

    function testShouldNotWithdrawOnBehalfIfNotAllowed() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC20: insufficient allowance");
        supplier1.redeem(daiSupplyHarvestVault, shares, address(supplier2));
    }

    function testShouldWithdrawOnBehalfIfAllowed() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyHarvestVault, amount);

        supplier1.approve(mchDai, address(supplier2), shares);
        supplier2.redeem(daiSupplyHarvestVault, shares, address(supplier1));
    }

    function testShouldNotDepositZeroAmount() public {
        vm.expectRevert(abi.encodeWithSignature("ShareIsZero()"));
        supplier1.deposit(daiSupplyHarvestVault, 0);
    }

    function testShouldNotMintZeroShare() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        supplier1.mint(daiSupplyHarvestVault, 0);
    }

    function testShouldNotWithdrawGreaterAmount() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        supplier1.deposit(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        supplier1.withdraw(daiSupplyHarvestVault, amount * 2);
    }

    function testShouldNotRedeemMoreShares() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyHarvestVault, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        supplier1.redeem(daiSupplyHarvestVault, shares + 1);
    }

    function testShouldClaimAndFoldRewards() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        supplier1.deposit(daiSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        morpho.updateP2PIndexes(address(cDai));
        Types.SupplyBalance memory supplyBalanceBefore = morpho.supplyBalanceInOf(
            address(cDai),
            address(daiSupplyHarvestVault)
        );

        (uint256 rewardsAmount, uint256 rewardsFee) = daiSupplyHarvestVault.harvest(
            daiSupplyHarvestVault.maxHarvestingSlippage()
        );
        uint256 expectedRewardsFee = ((rewardsAmount + rewardsFee) *
            daiSupplyHarvestVault.harvestingFee()) / daiSupplyHarvestVault.MAX_BASIS_POINTS();

        Types.SupplyBalance memory supplyBalanceAfter = morpho.supplyBalanceInOf(
            address(cDai),
            address(daiSupplyHarvestVault)
        );

        assertGt(rewardsAmount, 0, "rewards amount is zero");
        assertEq(
            supplyBalanceAfter.onPool,
            supplyBalanceBefore.onPool + rewardsAmount.div(cDai.exchangeRateCurrent()),
            "unexpected balance on pool"
        );
        assertEq(comp.balanceOf(address(daiSupplyHarvestVault)), 0, "comp amount is not zero");
        assertEq(rewardsFee, expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(dai.balanceOf(address(this)), rewardsFee, "unexpected fee collected");
    }

    function testShouldClaimAndRedeemRewards() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        uint256 shares = supplier1.deposit(daiSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        morpho.updateP2PIndexes(address(cDai));
        Types.SupplyBalance memory supplyBalanceBefore = morpho.supplyBalanceInOf(
            address(cDai),
            address(daiSupplyHarvestVault)
        );
        uint256 balanceBefore = supplier1.balanceOf(dai);

        (uint256 rewardsAmount, uint256 rewardsFee) = daiSupplyHarvestVault.harvest(
            daiSupplyHarvestVault.maxHarvestingSlippage()
        );
        uint256 expectedRewardsFee = ((rewardsAmount + rewardsFee) *
            daiSupplyHarvestVault.harvestingFee()) / daiSupplyHarvestVault.MAX_BASIS_POINTS();

        supplier1.redeem(daiSupplyHarvestVault, shares);
        uint256 balanceAfter = supplier1.balanceOf(dai);

        assertEq(dai.balanceOf(address(daiSupplyHarvestVault)), 0, "non zero dai balance on vault");
        assertGt(
            balanceAfter,
            balanceBefore + supplyBalanceBefore.onPool + rewardsAmount,
            "unexpected dai balance"
        );
        assertEq(rewardsFee, expectedRewardsFee, "unexpected rewards fee amount");
        assertEq(dai.balanceOf(address(this)), rewardsFee, "unexpected fee collected");
    }

    function testShouldNotAllowOracleDumpManipulation() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        supplier1.deposit(daiSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        uint256 flashloanAmount = 1_000 ether;
        ISwapRouter swapRouter = daiSupplyHarvestVault.SWAP_ROUTER();

        deal(address(comp), address(this), flashloanAmount);
        comp.approve(address(swapRouter), flashloanAmount);
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(comp),
                tokenOut: address(weth),
                fee: daiSupplyHarvestVault.compSwapFee(),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: flashloanAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        vm.expectRevert("Too little received");
        daiSupplyHarvestVault.harvest(100);
    }

    function testShouldNotAllowZeroSlippage() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, address(daiSupplyHarvestVault), amount);
        supplier1.deposit(daiSupplyHarvestVault, amount);

        vm.roll(block.number + 1_000);

        vm.expectRevert("Too little received");
        daiSupplyHarvestVault.harvest(0);
    }
}
