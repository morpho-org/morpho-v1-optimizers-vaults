// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestSupplyVaultBase is TestSetupVaults {
    function testShouldTransferRewardsToRecipient(address _caller, uint256 _amount) public {
        vm.assume(_amount > 0);

        assertEq(ERC20(MORPHO_TOKEN).balanceOf(RECIPIENT), 0);

        deal(MORPHO_TOKEN, address(daiSupplyVault), _amount);
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(daiSupplyVault)), _amount);

        vm.prank(_caller);
        daiSupplyVault.transferRewards();

        assertEq(ERC20(MORPHO_TOKEN).balanceOf(address(daiSupplyVault)), 0);
        assertEq(ERC20(MORPHO_TOKEN).balanceOf(RECIPIENT), _amount);
    }
}
