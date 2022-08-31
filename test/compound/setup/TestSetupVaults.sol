// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/compound/setup/TestSetup.sol";

import {SupplyVaultBase} from "@vaults/compound/SupplyVaultBase.sol";
import {SupplyHarvestVault} from "@vaults/compound/SupplyHarvestVault.sol";
import {SupplyVault} from "@vaults/compound/SupplyVault.sol";

import "@morpho-labs/morpho-utils/math/PercentageMath.sol";

import "../helpers/VaultUser.sol";

contract TestSetupVaults is TestSetup {
    using SafeTransferLib for ERC20;

    TransparentUpgradeableProxy internal wethSupplyVaultProxy;
    TransparentUpgradeableProxy internal wethSupplyHarvestVaultProxy;

    SupplyVault internal wethSupplyVaultImplV1;
    SupplyVault internal daiSupplyVaultImplV1;
    SupplyVault internal usdcSupplyVaultImplV1;
    SupplyHarvestVault internal wethSupplyHarvestVaultImplV1;
    SupplyHarvestVault internal daiSupplyHarvestVaultImplV1;
    SupplyHarvestVault internal usdcSupplyHarvestVaultImplV1;
    SupplyHarvestVault internal compSupplyHarvestVaultImplV1;

    SupplyVault internal wethSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;
    SupplyHarvestVault internal wethSupplyHarvestVault;
    SupplyHarvestVault internal daiSupplyHarvestVault;
    SupplyHarvestVault internal usdcSupplyHarvestVault;
    SupplyHarvestVault internal compSupplyHarvestVault;

    ERC20 mcWeth;
    ERC20 mcDai;
    ERC20 mcUsdc;
    ERC20 mchWeth;
    ERC20 mchDai;
    ERC20 mchUsdc;
    ERC20 mchComp;

    VaultUser public vaultSupplier1;
    VaultUser public vaultSupplier2;
    VaultUser public vaultSupplier3;
    VaultUser[] public vaultSuppliers;

    function onSetUp() public override {
        initVaultContracts();
        setVaultContractsLabels();
        initVaultUsers();
    }

    function initVaultContracts() internal {
        wethSupplyVaultImplV1 = new SupplyVault(address(morpho), cEth);
        daiSupplyVaultImplV1 = new SupplyVault(address(morpho), address(cDai));
        usdcSupplyVaultImplV1 = new SupplyVault(address(morpho), address(cUsdc));
        wethSupplyHarvestVaultImplV1 = new SupplyHarvestVault(address(morpho), cEth);
        daiSupplyHarvestVaultImplV1 = new SupplyHarvestVault(address(morpho), cDai);
        usdcSupplyHarvestVaultImplV1 = new SupplyHarvestVault(address(morpho), cUsdc);
        compSupplyHarvestVaultImplV1 = new SupplyHarvestVault(address(morpho), cComp);

        wethSupplyVaultProxy = new TransparentUpgradeableProxy(
            address(wethSupplyVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wethSupplyHarvestVaultProxy = new TransparentUpgradeableProxy(
            address(wethSupplyHarvestVaultImplV1),
            address(proxyAdmin),
            ""
        );

        wethSupplyHarvestVault = SupplyHarvestVault(address(wethSupplyHarvestVaultProxy));
        wethSupplyHarvestVault.initialize(
            "MorphoCompoundHarvestWETH",
            "mchWETH",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 0, 50)
        );
        mchWeth = ERC20(address(wethSupplyHarvestVault));

        daiSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(daiSupplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        daiSupplyHarvestVault.initialize(
            "MorphoCompoundHarvestDAI",
            "mchDAI",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, 100)
        );
        mchDai = ERC20(address(daiSupplyHarvestVault));

        usdcSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(usdcSupplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        usdcSupplyHarvestVault.initialize(
            "MorphoCompoundHarvestUSDC",
            "mchUSDC",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 3000, 50)
        );
        mchUsdc = ERC20(address(usdcSupplyHarvestVault));

        createMarket(cComp);
        compSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(compSupplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        compSupplyHarvestVault.initialize(
            "MorphoCompoundHarvestCOMP",
            "mchCOMP",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, 100)
        );
        mchComp = ERC20(address(compSupplyHarvestVault));

        wethSupplyVault = SupplyVault(address(wethSupplyVaultProxy));
        wethSupplyVault.initialize("MorphoCompoundWETH", "mcWETH", 0);
        mcWeth = ERC20(address(wethSupplyVault));

        daiSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(
                    address(daiSupplyVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        daiSupplyVault.initialize("MorphoCompoundDAI", "mcDAI", 0);
        mcDai = ERC20(address(daiSupplyVault));

        usdcSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(
                    address(usdcSupplyVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        usdcSupplyVault.initialize("MorphoCompoundUSDC", "mcUSDC", 0);
        mcUsdc = ERC20(address(usdcSupplyVault));
    }

    function initVaultUsers() internal {
        for (uint256 i = 0; i < 3; i++) {
            suppliers[i] = new VaultUser(morpho);
            fillUserBalances(suppliers[i]);
            deal(comp, address(suppliers[i]), INITIAL_BALANCE * WAD);

            vm.label(
                address(suppliers[i]),
                string(abi.encodePacked("VaultSupplier", Strings.toString(i + 1)))
            );
        }

        supplier1 = suppliers[0];
        supplier2 = suppliers[1];
        supplier3 = suppliers[2];

        vaultSupplier1 = VaultUser(payable(suppliers[0]));
        vaultSupplier2 = VaultUser(payable(suppliers[1]));
        vaultSupplier3 = VaultUser(payable(suppliers[2]));
    }

    function setVaultContractsLabels() internal {
        vm.label(address(wethSupplyVaultImplV1), "WETHSupplyVaultImplV1");
        vm.label(address(daiSupplyVaultImplV1), "DAISupplyVaultImplV1");
        vm.label(address(usdcSupplyVaultImplV1), "USDCSupplyVaultImplV1");

        vm.label(address(wethSupplyHarvestVaultImplV1), "WETHSupplyHarvestVaultImplV1");
        vm.label(address(daiSupplyHarvestVaultImplV1), "DAISupplyHarvestVaultImplV1");
        vm.label(address(usdcSupplyHarvestVaultImplV1), "USDCSupplyHarvestVaultImplV1");
        vm.label(address(compSupplyHarvestVaultImplV1), "USDCSupplyHarvestVaultImplV1");

        vm.label(address(wethSupplyVault), "SupplyVault (WETH)");
        vm.label(address(daiSupplyVault), "SupplyVault (DAI)");
        vm.label(address(usdcSupplyVault), "SupplyVault (USDC)");

        vm.label(address(wethSupplyHarvestVault), "SupplyHarvestVault (WETH)");
        vm.label(address(daiSupplyHarvestVault), "SupplyHarvestVault (DAI)");
        vm.label(address(usdcSupplyHarvestVault), "SupplyHarvestVault (USDC)");
        vm.label(address(compSupplyHarvestVault), "SupplyHarvestVault (COMP)");
    }
}
