// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/aave-v3/setup/TestSetup.sol";

import "@vaults/aave-v3/SupplyVault.sol";
import "@vaults/aave-v3/SupplyHarvestVault.sol";

import "../helpers/VaultUser.sol";

contract TestSetupVaults is TestSetup {
    using SafeTransferLib for ERC20;

    TransparentUpgradeableProxy internal wethSupplyVaultProxy;
    TransparentUpgradeableProxy internal wethSupplyHarvestVaultProxy;

    SupplyVault internal supplyVaultImplV1;
    SupplyHarvestVault internal supplyHarvestVaultImplV1;

    SupplyVault internal wethSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;
    SupplyHarvestVault internal wethSupplyHarvestVault;
    SupplyHarvestVault internal daiSupplyHarvestVault;
    SupplyHarvestVault internal usdcSupplyHarvestVault;

    ERC20 maWeth;
    ERC20 maDai;
    ERC20 maUsdc;
    ERC20 mahWeth;
    ERC20 mahDai;
    ERC20 mahUsdc;

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
        createMarket(aWeth);

        supplyVaultImplV1 = new SupplyVault();
        supplyHarvestVaultImplV1 = new SupplyHarvestVault();

        wethSupplyHarvestVaultProxy = new TransparentUpgradeableProxy(
            address(supplyHarvestVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wethSupplyHarvestVault = SupplyHarvestVault(address(wethSupplyHarvestVaultProxy));
        wethSupplyHarvestVault.initialize(
            address(morpho),
            aWeth,
            "MorphoAaveHarvestWETH",
            "mahWETH",
            0,
            50,
            100
        );
        mahWeth = ERC20(address(wethSupplyHarvestVault));

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
            aDai,
            "MorphoAaveHarvestDAI",
            "mahDAI",
            0,
            50,
            100
        );
        mahDai = ERC20(address(daiSupplyHarvestVault));

        usdcSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        deal(usdc, address(this), 50 ether);
        ERC20(usdc).safeApprove(address(usdcSupplyHarvestVault), 50 ether);
        usdcSupplyHarvestVault.initialize(
            address(morpho),
            aUsdc,
            "MorphoAaveHarvestUSDC",
            "mahUSDC",
            50 ether,
            50,
            100
        );
        // mahUsdc = ERC20(address(usdcSupplyHarvestVault));

        // wethSupplyVaultProxy = new TransparentUpgradeableProxy(
        //     address(supplyVaultImplV1),
        //     address(proxyAdmin),
        //     ""
        // );
        // wethSupplyVault = SupplyVault(address(wethSupplyVaultProxy));
        // wethSupplyVault.initialize(address(morpho), address(aWeth), "MorphoAaveWETH", "maWETH", 0);
        // maWeth = ERC20(address(wethSupplyVault));

        // daiSupplyVault = SupplyVault(
        //     address(
        //         new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
        //     )
        // );
        // daiSupplyVault.initialize(address(morpho), address(aDai), "MorphoAaveDAI", "maDAI", 0);
        // maDai = ERC20(address(daiSupplyVault));

        // usdcSupplyVault = SupplyVault(
        //     address(
        //         new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
        //     )
        // );
        // usdcSupplyVault.initialize(address(morpho), address(aUsdc), "MorphoAaveUSDC", "maUSDC", 0);
        // maUsdc = ERC20(address(usdcSupplyVault));
    }

    function initVaultUsers() internal {
        for (uint256 i = 0; i < 3; i++) {
            suppliers[i] = new VaultUser(morpho);
            fillUserBalances(suppliers[i]);

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
        vm.label(address(supplyHarvestVaultImplV1), "SupplyHarvestVaultImplV1");
        vm.label(address(wethSupplyHarvestVault), "SupplyHarvestVault (WETH)");
        vm.label(address(daiSupplyHarvestVault), "SupplyHarvestVault (DAI)");
        vm.label(address(usdcSupplyHarvestVault), "SupplyHarvestVault (USDC)");
    }
}
