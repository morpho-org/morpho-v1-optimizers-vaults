// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyVaultBase is TestSetupVaults {
    function testShouldTransferRewardsToRecipient(uint256 _amount) public {
        vm.assume(_amount > 0);
        _prepareTransfer(_amount);

        daiSupplyVault.transferRewards();

        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(daiSupplyVault)), 0);
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(RECIPIENT), _amount);
    }

    function _prepareTransfer(uint256 _amount) internal {
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(RECIPIENT), 0);

        deal(MORPHO_TOKEN, address(daiSupplyVault), _amount);
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(daiSupplyVault)), _amount);

        // Allow the vault to transfer rewards.
        vm.prank(MORPHO_DAO);
        IRolesAuthority(MORPHO_TOKEN).setUserRole(address(daiSupplyVault), 0, true);
    }
}
