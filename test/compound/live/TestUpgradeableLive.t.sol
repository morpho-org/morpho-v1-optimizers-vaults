// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "../setup/TestSetupVaultsLive.sol";

contract TestUpgradeableLive is TestSetupVaultsLive {
    using CompoundMath for uint256;

    function testUpgradeSupplyHarvestVault() public {
        SupplyHarvestVault wethSupplyHarvestVaultImplV2 = new SupplyHarvestVault();

        vm.record();
        vm.prank(OWNER);
        proxyAdmin.upgrade(wethSupplyHarvestVaultProxy, address(wethSupplyHarvestVaultImplV2));
        (, bytes32[] memory writes) = vm.accesses(address(wethSupplyHarvestVault));

        // 1 write for the implemention.
        assertEq(writes.length, 1);
        address newImplem = bytes32ToAddress(
            vm.load(
                address(wethSupplyHarvestVault),
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1) // Implementation slot.
            )
        );
        assertEq(newImplem, address(wethSupplyHarvestVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeSupplyHarvestVault() public {
        SupplyHarvestVault supplyHarvestVaultImplV2 = new SupplyHarvestVault();

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(wethSupplyHarvestVaultProxy, address(supplyHarvestVaultImplV2));

        vm.prank(OWNER);
        proxyAdmin.upgrade(wethSupplyHarvestVaultProxy, address(supplyHarvestVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallSupplyHarvestVault() public {
        SupplyHarvestVault wethSupplyHarvestVaultImplV2 = new SupplyHarvestVault();

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(
            wethSupplyHarvestVaultProxy,
            payable(address(wethSupplyHarvestVaultImplV2)),
            ""
        );

        // Revert for wrong data not wrong caller.
        vm.prank(OWNER);
        vm.expectRevert("Address: low-level delegate call failed");
        proxyAdmin.upgradeAndCall(
            wethSupplyHarvestVaultProxy,
            payable(address(wethSupplyHarvestVaultImplV2)),
            ""
        );
    }

    function testSupplyHarvestVaultImplementationsShouldBeInitialized() public {
        vm.prank(OWNER);
        vm.expectRevert("Initializable: contract is already initialized");
        supplyHarvestVaultImplV1.initialize(
            address(morpho),
            address(cEth),
            "MorphoCompoundETH",
            "mcETH",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, 50)
        );
    }

    function testUpgradeSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault();

        vm.record();
        vm.prank(OWNER);
        proxyAdmin.upgrade(wethSupplyVaultProxy, address(wethSupplyVaultImplV2));
        (, bytes32[] memory writes) = vm.accesses(address(wethSupplyVault));

        // 1 write for the implemention.
        assertEq(writes.length, 1);
        address newImplem = bytes32ToAddress(
            vm.load(
                address(wethSupplyVault),
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1) // Implementation slot.
            )
        );
        assertEq(newImplem, address(wethSupplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeSupplyVault() public {
        SupplyVault supplyVaultImplV2 = new SupplyVault();

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(wethSupplyVaultProxy, address(supplyVaultImplV2));

        vm.prank(OWNER);
        proxyAdmin.upgrade(wethSupplyVaultProxy, address(supplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault();

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(
            wethSupplyVaultProxy,
            payable(address(wethSupplyVaultImplV2)),
            ""
        );

        // Revert for wrong data not wrong caller.
        vm.prank(OWNER);
        vm.expectRevert("Address: low-level delegate call failed");
        proxyAdmin.upgradeAndCall(
            wethSupplyVaultProxy,
            payable(address(wethSupplyVaultImplV2)),
            ""
        );
    }

    function testSupplyVaultImplementationsShouldBeInitialized() public {
        vm.prank(OWNER);
        vm.expectRevert("Initializable: contract is already initialized");
        supplyVaultImplV1.initialize(
            address(morpho),
            address(cEth),
            "MorphoCompoundETH",
            "mcETH",
            0
        );
    }
}
