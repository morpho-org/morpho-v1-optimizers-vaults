// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@tests/aave-v2/setup/TestSetup.sol";

import {SupplyVaultBase} from "@vaults/aave-v2/SupplyVaultBase.sol";
import {SupplyVault} from "@vaults/aave-v2/SupplyVault.sol";

import "../../helpers/FakeToken.sol";
import "../helpers/VaultUser.sol";

contract TestSetupVaults is TestSetup {
    using SafeTransferLib for ERC20;

    TransparentUpgradeableProxy internal wNativeSupplyVaultProxy;

    SupplyVault internal supplyVaultImplV1;

    SupplyVault internal wNativeSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;

    ERC20 internal ma2WNative;
    ERC20 internal ma2Dai;
    ERC20 internal ma2Usdc;

    VaultUser public vaultSupplier1;
    VaultUser public vaultSupplier2;
    VaultUser public vaultSupplier3;
    VaultUser[] public vaultSuppliers;

    FakeToken public token;
    address public $token;

    function onSetUp() public override {
        initVaultContracts();
        initVaultUsers();

        token = new FakeToken("Token", "TKN");
        $token = address(token);
    }

    function initVaultContracts() internal {
        supplyVaultImplV1 = new SupplyVault(address(morpho));

        wNativeSupplyVaultProxy = new TransparentUpgradeableProxy(
            address(supplyVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wNativeSupplyVault = SupplyVault(address(wNativeSupplyVaultProxy));
        wNativeSupplyVault.initialize(aWeth, "MorphoAave2WETH", "ma2WETH", 0);
        ma2WNative = ERC20(address(wNativeSupplyVault));

        daiSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        daiSupplyVault.initialize(address(aDai), "MorphoAave2DAI", "ma2DAI", 0);
        ma2Dai = ERC20(address(daiSupplyVault));

        usdcSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        usdcSupplyVault.initialize(address(aUsdc), "MorphoAave2USDC", "ma2USDC", 0);
        ma2Usdc = ERC20(address(usdcSupplyVault));
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
}
