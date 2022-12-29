// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestUpgradeable is TestSetupVaults {
    using WadRayMath for uint256;

    function testUpgradeSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault(
            address(morpho),
            MORPHO_TOKEN,
            RECIPIENT
        );

        vm.record();
        proxyAdmin.upgrade(wrappedNativeTokenSupplyVaultProxy, address(wethSupplyVaultImplV2));
        (, bytes32[] memory writes) = vm.accesses(address(wrappedNativeTokenSupplyVault));

        // 1 write for the implemention.
        assertEq(writes.length, 1);
        address newImplem = bytes32ToAddress(
            vm.load(
                address(wrappedNativeTokenSupplyVault),
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1) // Implementation slot.
            )
        );
        assertEq(newImplem, address(wethSupplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeSupplyVault() public {
        SupplyVault supplyVaultImplV2 = new SupplyVault(address(morpho), MORPHO_TOKEN, RECIPIENT);

        vm.prank(address(vaultSupplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(wrappedNativeTokenSupplyVaultProxy, address(supplyVaultImplV2));

        proxyAdmin.upgrade(wrappedNativeTokenSupplyVaultProxy, address(supplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault(
            address(morpho),
            MORPHO_TOKEN,
            RECIPIENT
        );

        vm.prank(address(vaultSupplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(
            wrappedNativeTokenSupplyVaultProxy,
            payable(address(wethSupplyVaultImplV2)),
            ""
        );

        // Revert for wrong data not wrong caller.
        vm.expectRevert("Address: low-level delegate call failed");
        proxyAdmin.upgradeAndCall(
            wrappedNativeTokenSupplyVaultProxy,
            payable(address(wethSupplyVaultImplV2)),
            ""
        );
    }

    function testSupplyVaultImplementationsShouldBeInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        supplyVaultImplV1.initialize(address(aWrappedNativeToken), "MorphoAaveWETH", "maWETH", 0);
    }
}
