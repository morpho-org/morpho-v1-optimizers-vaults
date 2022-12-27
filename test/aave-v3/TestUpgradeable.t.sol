// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetupVaults.sol";

contract TestUpgradeable is TestSetupVaults {
    using WadRayMath for uint256;

    function testUpgradeSupplyHarvestVault() public {
        SupplyHarvestVault wethSupplyHarvestVaultImplV2 = new SupplyHarvestVault(address(morpho));

        vm.record();
        proxyAdmin.upgrade(
            wrappedNativeTokenSupplyHarvestVaultProxy,
            address(wethSupplyHarvestVaultImplV2)
        );
        (, bytes32[] memory writes) = vm.accesses(address(wrappedNativeTokenSupplyHarvestVault));

        // 1 write for the implemention.
        assertEq(writes.length, 1);
        address newImplem = bytes32ToAddress(
            vm.load(
                address(wrappedNativeTokenSupplyHarvestVault),
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1) // Implementation slot.
            )
        );
        assertEq(newImplem, address(wethSupplyHarvestVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeSupplyHarvestVault() public {
        SupplyHarvestVault supplyHarvestVaultImplV2 = new SupplyHarvestVault(address(morpho));

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(
            wrappedNativeTokenSupplyHarvestVaultProxy,
            address(supplyHarvestVaultImplV2)
        );

        proxyAdmin.upgrade(
            wrappedNativeTokenSupplyHarvestVaultProxy,
            address(supplyHarvestVaultImplV2)
        );
    }

    function testOnlyProxyOwnerCanUpgradeAndCallSupplyHarvestVault() public {
        SupplyHarvestVault wethSupplyHarvestVaultImplV2 = new SupplyHarvestVault(address(morpho));

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(
            wrappedNativeTokenSupplyHarvestVaultProxy,
            payable(address(wethSupplyHarvestVaultImplV2)),
            ""
        );

        // Revert for wrong data not wrong caller.
        vm.expectRevert("Address: low-level delegate call failed");
        proxyAdmin.upgradeAndCall(
            wrappedNativeTokenSupplyHarvestVaultProxy,
            payable(address(wethSupplyHarvestVaultImplV2)),
            ""
        );
    }

    function testSupplyHarvestVaultImplementationsShouldBeInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        supplyHarvestVaultImplV1.initialize(
            address(aWrappedNativeToken),
            "MorphoAaveWETH",
            "mahWETH",
            0,
            10,
            rewardToken
        );
    }

    function testUpgradeSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault(address(morpho));

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
        SupplyVault supplyVaultImplV2 = new SupplyVault(address(morpho));

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(wrappedNativeTokenSupplyVaultProxy, address(supplyVaultImplV2));

        proxyAdmin.upgrade(wrappedNativeTokenSupplyVaultProxy, address(supplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault(address(morpho));

        vm.prank(address(supplier1));
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
