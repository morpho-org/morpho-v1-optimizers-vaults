// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestUpgradeable is TestSetupVaults {
    using WadRayMath for uint256;

    function testUpgradeSupplyVault() public {
        SupplyVault wNativeSupplyVaultImplV2 = new SupplyVault(address(morpho), MORPHO_TOKEN, LENS);

        vm.record();
        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(wNativeSupplyVaultImplV2));
        (, bytes32[] memory writes) = vm.accesses(address(wNativeSupplyVault));

        // 1 write for the implemention.
        assertEq(writes.length, 1);
        address newImplem = bytes32ToAddress(
            vm.load(
                address(wNativeSupplyVault),
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1) // Implementation slot.
            )
        );
        assertEq(newImplem, address(wNativeSupplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeSupplyVault() public {
        SupplyVault supplyVaultImplV2 = new SupplyVault(address(morpho), MORPHO_TOKEN, LENS);

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(supplyVaultImplV2));

        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(supplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallSupplyVault() public {
        SupplyVault wNativeSupplyVaultImplV2 = new SupplyVault(address(morpho), MORPHO_TOKEN, LENS);

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(
            wNativeSupplyVaultProxy,
            payable(address(wNativeSupplyVaultImplV2)),
            ""
        );

        // Revert for wrong data not wrong caller.
        vm.expectRevert("Address: low-level delegate call failed");
        proxyAdmin.upgradeAndCall(
            wNativeSupplyVaultProxy,
            payable(address(wNativeSupplyVaultImplV2)),
            ""
        );
    }

    function testSupplyVaultImplementationsShouldBeInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        supplyVaultImplV1.initialize(address(aWeth), "MorphoAave2WETH", "ma2WETH", 0);
    }
}
