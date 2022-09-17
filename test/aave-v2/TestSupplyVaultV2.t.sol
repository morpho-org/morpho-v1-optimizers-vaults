// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "src/aave-v2/SupplyVaultV2.sol";
import "./setup/TestSetupVaults.sol";
import "../helpers/FakeToken.sol";

contract TestSupplyVaultV2 is TestSetupVaults {
    SupplyVaultV2 public supplyVaultImplV2;
    SupplyVaultV2 public supplyVaultV2;
    FakeToken public token;
    address public $token;

    function onSetUp() public virtual override {
        super.onSetUp();

        supplyVaultImplV2 = new SupplyVaultV2(address(morpho));

        vm.prank(proxyAdmin.owner());
        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(supplyVaultImplV2));
        supplyVaultV2 = SupplyVaultV2(address(wNativeSupplyVaultProxy));

        token = new FakeToken("Token", "TKN");
        $token = address(token);
    }

    function testNotOwnerShouldNotTransferTokens(
        address _caller,
        address _receiver,
        uint256 _amount
    ) public {
        vm.assume(_caller != supplyVaultV2.owner());
        vm.prank(_caller);
        vm.expectRevert("Ownable: caller is not the owner");
        supplyVaultV2.transferTokens($token, _receiver, _amount);
    }

    function testOwnerShouldTransferTokens(
        address _to,
        uint256 _deal,
        uint256 _toTransfer
    ) public {
        _toTransfer = bound(_toTransfer, 0, _deal);
        deal($token, address(supplyVaultV2), _deal);

        vm.prank(supplyVaultV2.owner());
        supplyVaultV2.transferTokens($token, _to, _toTransfer);

        assertEq(token.balanceOf(address(supplyVaultV2)), _deal - _toTransfer);
        assertEq(token.balanceOf(_to), _toTransfer);
    }
}
