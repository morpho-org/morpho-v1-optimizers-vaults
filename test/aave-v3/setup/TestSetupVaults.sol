// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@tests/aave-v3/setup/TestSetup.sol";
import {SupplyVaultBase} from "@vaults/aave-v3/SupplyVaultBase.sol";
import {SupplyVault} from "@vaults/aave-v3/SupplyVault.sol";

import "../../helpers/FakeToken.sol";
import "../helpers/VaultUser.sol";
import "../helpers/SupplyVaultBaseMock.sol";

contract TestSetupVaults is TestSetup {
    using SafeTransferLib for ERC20;

    address internal MORPHO_TOKEN = address(new FakeToken("Morpho Token", "MORPHO"));
    address internal constant MORPHO_DAO = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;
    address internal constant RECIPIENT = 0x60345417a227ad7E312eAa1B5EC5CD1Fe5E2Cdc6;

    TransparentUpgradeableProxy internal wrappedNativeTokenSupplyVaultProxy;

    SupplyVault internal supplyVaultImplV1;

    SupplyVault internal wrappedNativeTokenSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;
    SupplyVaultBase internal supplyVaultBase;

    ERC20 internal maWrappedNativeToken;
    ERC20 internal maDai;
    ERC20 internal maUsdc;

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
        createMarket(aWrappedNativeToken);

        supplyVaultImplV1 = new SupplyVault(address(morpho), MORPHO_TOKEN, RECIPIENT);
        supplyVaultBase = SupplyVaultBase(
            address(
                new TransparentUpgradeableProxy(
                    address(new SupplyVaultBaseMock(address(morpho), MORPHO_TOKEN, RECIPIENT)),
                    address(proxyAdmin),
                    ""
                )
            )
        );

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

        supplier1 = suppliers[0];
        supplier2 = suppliers[1];
        supplier3 = suppliers[2];

        vaultSupplier1 = VaultUser(payable(suppliers[0]));
        vaultSupplier2 = VaultUser(payable(suppliers[1]));
        vaultSupplier3 = VaultUser(payable(suppliers[2]));
    }

    function setVaultContractsLabels() internal {
        vm.label(address(wrappedNativeTokenSupplyVault), "SupplyVault (WNATIVE)");
        vm.label(address(usdcSupplyVault), "SupplyVault (USDC)");
        vm.label(address(daiSupplyVault), "SupplyVault (DAI)");
    }
}
