// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/aave-v3/setup/TestSetup.sol";

import "@vaults/aave-v3/SupplyVault.sol";
import "@vaults/aave-v3/SupplyHarvestVault.sol";

import "../helpers/VaultUser.sol";

contract TestSetupVaults is TestSetup {
    using SafeTransferLib for ERC20;

    TransparentUpgradeableProxy internal wNativeSupplyVaultProxy;
    TransparentUpgradeableProxy internal wNativeSupplyHarvestVaultProxy;

    SupplyVault internal supplyVaultImplV1;
    SupplyHarvestVault internal supplyHarvestVaultImplV1;

    SupplyVault internal wNativeSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;
    SupplyHarvestVault internal wNativeSupplyHarvestVault;
    SupplyHarvestVault internal daiSupplyHarvestVault;
    SupplyHarvestVault internal usdcSupplyHarvestVault;

    address internal aWrappedNativeToken;
    address internal wrappedNativeToken;

    ERC20 maWrappedNative;
    ERC20 maDai;
    ERC20 maUsdc;
    ERC20 mahWrappedNative;
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
        if (block.chainid == Chains.AVALANCHE_MAINNET) {
            aWrappedNativeToken = avWavax;
            wrappedNativeToken = wavax;
        }

        console.log(aWrappedNativeToken);

        createMarket(aWrappedNativeToken);

        supplyVaultImplV1 = new SupplyVault();
        supplyHarvestVaultImplV1 = new SupplyHarvestVault();

        wNativeSupplyHarvestVaultProxy = new TransparentUpgradeableProxy(
            address(supplyHarvestVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wNativeSupplyHarvestVault = SupplyHarvestVault(address(wNativeSupplyHarvestVaultProxy));
        wNativeSupplyHarvestVault.initialize(
            address(morpho),
            aWrappedNativeToken,
            "MorphoAaveHarvestWNATIVE",
            "mahWNATIVE",
            0,
            50,
            100,
            wrappedNativeToken
        );
        mahWrappedNative = ERC20(address(wNativeSupplyHarvestVault));

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
            100,
            wrappedNativeToken
        );
        mahDai = ERC20(address(daiSupplyHarvestVault));

        uint256 initialUsdcDeposit = 1000e6;
        usdcSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        deal(usdc, address(this), initialUsdcDeposit);
        ERC20(usdc).safeApprove(address(usdcSupplyHarvestVault), initialUsdcDeposit);
        usdcSupplyHarvestVault.initialize(
            address(morpho),
            aUsdc,
            "MorphoAaveHarvestUSDC",
            "mahUSDC",
            initialUsdcDeposit,
            50,
            100,
            wrappedNativeToken
        );
        mahUsdc = ERC20(address(usdcSupplyHarvestVault));

        wNativeSupplyVaultProxy = new TransparentUpgradeableProxy(
            address(supplyVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wNativeSupplyVault = SupplyVault(address(wNativeSupplyVaultProxy));
        wNativeSupplyVault.initialize(
            address(morpho),
            address(aWrappedNativeToken),
            "MorphoAaveWNATIVE",
            "maWNATIVE",
            0
        );
        maWrappedNative = ERC20(address(wNativeSupplyVault));

        daiSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        daiSupplyVault.initialize(address(morpho), address(aDai), "MorphoAaveDAI", "maDAI", 0);
        maDai = ERC20(address(daiSupplyVault));

        usdcSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        usdcSupplyVault.initialize(address(morpho), address(aUsdc), "MorphoAaveUSDC", "maUSDC", 0);
        maUsdc = ERC20(address(usdcSupplyVault));
    }

    function initVaultUsers() internal {
        for (uint256 i = 0; i < 3; i++) {
            suppliers[i] = new VaultUser(morpho);
            fillUserBalances(suppliers[i]);

            deal(wrappedNativeToken, address(suppliers[i]), 10000000 ether);

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
        vm.label(address(wNativeSupplyHarvestVault), "SupplyHarvestVault (wNATIVE)");
        vm.label(address(daiSupplyHarvestVault), "SupplyHarvestVault (DAI)");
        vm.label(address(usdcSupplyHarvestVault), "SupplyHarvestVault (USDC)");
    }
}
