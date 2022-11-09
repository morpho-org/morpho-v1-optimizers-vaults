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

    function testCannotTransferRewardsToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyVaultBase.ZeroAddress.selector));
        daiSupplyVault.transferRewards();
    }

    function testNotOwnerShouldNotTransferRewardsToRecipient(uint256 _amount) public {
        vm.assume(_amount > 0);
        _prepareTransfer(_amount);

        vm.startPrank(address(2));
        vm.expectRevert("Ownable: caller is not the owner");
        daiSupplyVault.transferRewards();
    }

    function testOwnerShouldTransferRewardsToRecipient(uint256 _amount) public {
        vm.assume(_amount > 0);
        _prepareTransfer(_amount);

        daiSupplyVault.transferRewards();

        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(daiSupplyVault)), 0);
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(1)), _amount);
    }

    function _prepareTransfer(uint256 _amount) internal {
        daiSupplyVault.setRewardsRecipient(address(1));
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(1)), 0);

        deal(MORPHO_TOKEN, address(daiSupplyVault), _amount);
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(daiSupplyVault)), _amount);
    }
}
