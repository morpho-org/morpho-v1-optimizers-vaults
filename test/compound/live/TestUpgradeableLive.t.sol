// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "../setup/TestSetupVaultsLive.sol";

contract TestUpgradeableLive is TestSetupVaultsLive {
    using CompoundMath for uint256;

    function testUpgradeSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault(
            address(morpho),
            MORPHO_TOKEN,
            address(lens)
        );

        vm.record();
        vm.prank(PROXY_ADMIN_OWNER);
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
        SupplyVault supplyVaultImplV2 = new SupplyVault(
            address(morpho),
            MORPHO_TOKEN,
            address(lens)
        );

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(wethSupplyVaultProxy, address(supplyVaultImplV2));

        vm.prank(PROXY_ADMIN_OWNER);
        proxyAdmin.upgrade(wethSupplyVaultProxy, address(supplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault(
            address(morpho),
            MORPHO_TOKEN,
            address(lens)
        );

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(
            wethSupplyVaultProxy,
            payable(address(wethSupplyVaultImplV2)),
            ""
        );

        // Revert for wrong data not wrong caller.
        vm.prank(PROXY_ADMIN_OWNER);
        vm.expectRevert("Address: low-level delegate call failed");
        proxyAdmin.upgradeAndCall(
            wethSupplyVaultProxy,
            payable(address(wethSupplyVaultImplV2)),
            ""
        );
    }

    function testSupplyVaultImplementationsShouldBeInitialized() public {
        vm.prank(PROXY_ADMIN_OWNER);
        vm.expectRevert("Initializable: contract is already initialized");
        supplyVaultImplV1.initialize(address(cEth), "MorphoCompoundETH", "mcETH", 0);
    }
}
