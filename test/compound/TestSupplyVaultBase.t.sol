// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyVaultBase is TestSetupVaults {
    function testNotOwnerShouldNotSetRecipient() public {
        vm.prank(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyVault.setRewardsRecipient(address(1));
    }

    function testOwnerShouldSetRecipient() public {
        daiSupplyVault.setRewardsRecipient(address(1));
        assertEq(daiSupplyVault.recipient(), address(1));
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
}
