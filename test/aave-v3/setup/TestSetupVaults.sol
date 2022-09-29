// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import {ISwapper} from "@vaults/interfaces/ISwapper.sol";

import "@tests/aave-v3/setup/TestSetup.sol";
import {SupplyVaultBase} from "@vaults/aave-v3/SupplyVaultBase.sol";
import {SupplyHarvestVault} from "@vaults/aave-v3/SupplyHarvestVault.sol";
import {SupplyVault} from "@vaults/aave-v3/SupplyVault.sol";
import {UniswapV2Swapper} from "@vaults/UniswapV2Swapper.sol";
import {UniswapV3Swapper} from "@vaults/UniswapV3Swapper.sol";

import "../../helpers/FakeToken.sol";
import "../helpers/VaultUser.sol";

contract TestSetupVaults is TestSetup {
    using SafeTransferLib for ERC20;

    TransparentUpgradeableProxy internal wrappedNativeTokenSupplyVaultProxy;
    TransparentUpgradeableProxy internal wrappedNativeTokenSupplyHarvestVaultProxy;

    SupplyVault internal supplyVaultImplV1;
    SupplyHarvestVault internal supplyHarvestVaultImplV1;

    SupplyVault internal wrappedNativeTokenSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;
    SupplyHarvestVault internal wrappedNativeTokenSupplyHarvestVault;
    SupplyHarvestVault internal daiSupplyHarvestVault;
    SupplyHarvestVault internal usdcSupplyHarvestVault;

    ISwapper internal swapper;

    ERC20 internal maWrappedNativeToken;
    ERC20 internal maDai;
    ERC20 internal maUsdc;
    ERC20 internal mahWrappedNativeToken;
    ERC20 internal mahDai;
    ERC20 internal mahUsdc;

    VaultUser public vaultSupplier1;
    VaultUser public vaultSupplier2;
    VaultUser public vaultSupplier3;
    VaultUser[] public vaultSuppliers;

    FakeToken public token;
    address public $token;

    function onSetUp() public override {
        initVaultContracts();
        setVaultContractsLabels();
        initVaultUsers();

        token = new FakeToken("Token", "TKN");
        $token = address(token);
    }

    function initVaultContracts() internal {
        if (block.chainid == Chains.AVALANCHE_MAINNET) {
            swapper = new UniswapV2Swapper(0x60aE616a2155Ee3d9A68541Ba4544862310933d4, wavax);
            vm.label(0x60aE616a2155Ee3d9A68541Ba4544862310933d4, "Uniswap V2");
            vm.label(address(swapper), "Swapper");
        }

        createMarket(aWrappedNativeToken);

        supplyVaultImplV1 = new SupplyVault(address(morpho));
        supplyHarvestVaultImplV1 = new SupplyHarvestVault(address(morpho));

        wrappedNativeTokenSupplyHarvestVaultProxy = new TransparentUpgradeableProxy(
            address(supplyHarvestVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wrappedNativeTokenSupplyHarvestVault = SupplyHarvestVault(
            address(wrappedNativeTokenSupplyHarvestVaultProxy)
        );
        wrappedNativeTokenSupplyHarvestVault.initialize(
            aWrappedNativeToken,
            "MorphoAaveHarvestWNATIVE",
            "mahWNATIVE",
            0,
            50,
            address(swapper)
        );
        mahWrappedNativeToken = ERC20(address(wrappedNativeTokenSupplyHarvestVault));

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
            aDai,
            "MorphoAaveHarvestDAI",
            "mahDAI",
            0,
            50,
            address(swapper)
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

        usdcSupplyHarvestVault.initialize(
            aUsdc,
            "MorphoAaveHarvestUSDC",
            "mahUSDC",
            0,
            50,
            address(swapper)
        );
        mahUsdc = ERC20(address(usdcSupplyHarvestVault));

        wrappedNativeTokenSupplyVaultProxy = new TransparentUpgradeableProxy(
            address(supplyVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wrappedNativeTokenSupplyVault = SupplyVault(address(wrappedNativeTokenSupplyVaultProxy));
        wrappedNativeTokenSupplyVault.initialize(
            address(aWrappedNativeToken),
            "MorphoAaveWNATIVE",
            "maWNATIVE",
            0
        );
        maWrappedNativeToken = ERC20(address(wrappedNativeTokenSupplyVault));

        daiSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        daiSupplyVault.initialize(address(aDai), "MorphoAaveDAI", "maDAI", 0);
        maDai = ERC20(address(daiSupplyVault));

        usdcSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        usdcSupplyVault.initialize(address(aUsdc), "MorphoAaveUSDC", "maUSDC", 0);
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

        vaultSupplier1 = VaultUser(payable(suppliers[0]));
        vaultSupplier2 = VaultUser(payable(suppliers[1]));
        vaultSupplier3 = VaultUser(payable(suppliers[2]));
    }

    function setVaultContractsLabels() internal {
        vm.label(address(supplyHarvestVaultImplV1), "SupplyHarvestVaultImplV1");
        vm.label(address(wrappedNativeTokenSupplyHarvestVault), "SupplyHarvestVault (wNATIVE)");
        vm.label(address(daiSupplyHarvestVault), "SupplyHarvestVault (DAI)");
        vm.label(address(usdcSupplyHarvestVault), "SupplyHarvestVault (USDC)");
    }
}
