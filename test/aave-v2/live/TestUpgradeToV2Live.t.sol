// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "src/aave-v2/SupplyVaultV2.sol";
import "../setup/TestSetupVaultsLive.sol";

contract TestUpgradeToV2Live is TestSetupVaultsLive {
    using WadRayMath for uint256;

    function testUpgradeSupplyVault() public {
        SupplyVaultV2 wNativeSupplyVaultImplV2 = new SupplyVaultV2(address(morpho));

        vm.record();
        vm.prank(PROXY_ADMIN_OWNER);
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
        SupplyVaultV2 supplyVaultImplV2 = new SupplyVaultV2(address(morpho));

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(supplyVaultImplV2));

        vm.prank(PROXY_ADMIN_OWNER);
        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(supplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallSupplyVault() public {
        SupplyVaultV2 wNativeSupplyVaultImplV2 = new SupplyVaultV2(address(morpho));

        vm.prank(address(supplier1));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(
            wNativeSupplyVaultProxy,
            payable(address(wNativeSupplyVaultImplV2)),
            ""
        );

        // Revert for wrong data not wrong caller.
        vm.prank(PROXY_ADMIN_OWNER);
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

    function testSupplyVaultShouldBeInitializedWithRightOwner() public {
        SupplyVaultV2 supplyVaultImplV2 = new SupplyVaultV2(address(morpho));
        vm.prank(PROXY_ADMIN_OWNER);
        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(supplyVaultImplV2));
        SupplyVaultV2 supplyVaultV2 = SupplyVaultV2(address(wNativeSupplyVaultProxy));

        assertEq(supplyVaultV2.upgradedToV2(), false);
        assertEq(supplyVaultV2.owner(), address(0));

        supplyVaultV2.initialize();

        assertEq(supplyVaultV2.upgradedToV2(), true);
        assertEq(supplyVaultV2.owner(), address(this));

        vm.expectRevert("already upgraded to V2");
        supplyVaultV2.initialize();
    }
}
