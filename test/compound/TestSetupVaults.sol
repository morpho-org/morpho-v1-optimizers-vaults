// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@morpho-contracts/test-foundry/compound/setup/TestSetup.sol";

import "@contracts/compound/SupplyHarvestVault.sol";

contract TestSetupVaults is TestSetup {
    using CompoundMath for uint256;

    TransparentUpgradeableProxy internal wEthSupplyHarvestVaultProxy;

    SupplyHarvestVault internal supplyHarvestVaultImplV1;

    SupplyHarvestVault internal wEthSupplyHarvestVault;
    SupplyHarvestVault internal daiSupplyHarvestVault;
    SupplyHarvestVault internal usdcSupplyHarvestVault;

    function onSetUp() public override {
        supplyHarvestVaultImplV1 = new SupplyHarvestVault();
        wEthSupplyHarvestVaultProxy = new TransparentUpgradeableProxy(
            address(supplyHarvestVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wEthSupplyHarvestVault = SupplyHarvestVault(address(wEthSupplyHarvestVaultProxy));
        wEthSupplyHarvestVault.initialize(
            address(morpho),
            cEth,
            "MorphoCompoundWETH",
            "mcWETH",
            0,
            3000,
            0,
            50,
            100,
            cComp
        );

        daiSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        daiSupplyHarvestVault.initialize(
            address(morpho),
            cDai,
            "MorphoCompoundDAI",
            "mcDAI",
            0,
            3000,
            500,
            50,
            100,
            cComp
        );

        usdcSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        usdcSupplyHarvestVault.initialize(
            address(morpho),
            cUsdc,
            "MorphoCompoundUSDC",
            "mcUSDC",
            0,
            3000,
            500,
            50,
            100,
            cComp
        );
    }
}
