// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/compound/setup/TestSetup.sol";

import {SupplyVaultBase} from "@vaults/compound/SupplyVaultBase.sol";
import {SupplyHarvestVault} from "@vaults/compound/SupplyHarvestVault.sol";
import {SupplyVault} from "@vaults/compound/SupplyVault.sol";

import "@morpho-labs/morpho-utils/math/PercentageMath.sol";

import "../../helpers/interfaces/IRolesAuthority.sol";
import "../../helpers/FakeToken.sol";
import "../helpers/VaultUser.sol";

contract TestSetupVaults is TestSetup {
    using SafeTransferLib for ERC20;

    address internal constant MORPHO_DAO = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;
    address internal constant MORPHO_TOKEN = 0x9994E35Db50125E0DF82e4c2dde62496CE330999;

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
    SupplyHarvestVault internal compSupplyHarvestVault;

    ERC20 internal mcWeth;
    ERC20 internal mcDai;
    ERC20 internal mcUsdc;
    ERC20 internal mchWeth;
    ERC20 internal mchDai;
    ERC20 internal mchUsdc;
    ERC20 internal mchComp;

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
        supplyVaultImplV1 = new SupplyVault(address(morpho));
        supplyHarvestVaultImplV1 = new SupplyHarvestVault(address(morpho));

        wethSupplyHarvestVaultProxy = new TransparentUpgradeableProxy(
            address(supplyHarvestVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wethSupplyHarvestVault = SupplyHarvestVault(address(wethSupplyHarvestVaultProxy));
        wethSupplyHarvestVault.initialize(
            cEth,
            "MorphoCompoundHarvestWETH",
            "mchWETH",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 0, 50)
        );
        mchWeth = ERC20(address(wethSupplyHarvestVault));

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
            cDai,
            "MorphoCompoundHarvestDAI",
            "mchDAI",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, 100)
        );
        mchDai = ERC20(address(daiSupplyHarvestVault));

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
            cUsdc,
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
                    address(supplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        compSupplyHarvestVault.initialize(
            cComp,
            "MorphoCompoundHarvestCOMP",
            "mchCOMP",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, 100)
        );
        mchComp = ERC20(address(compSupplyHarvestVault));

        wethSupplyVaultProxy = new TransparentUpgradeableProxy(
            address(supplyVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wethSupplyVault = SupplyVault(address(wethSupplyVaultProxy));
        wethSupplyVault.initialize(cEth, "MorphoCompoundWETH", "mcWETH", 0);
        mcWeth = ERC20(address(wethSupplyVault));

        daiSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        daiSupplyVault.initialize(address(cDai), "MorphoCompoundDAI", "mcDAI", 0);
        mcDai = ERC20(address(daiSupplyVault));

        usdcSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        usdcSupplyVault.initialize(address(cUsdc), "MorphoCompoundUSDC", "mcUSDC", 0);
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
        vm.label(address(supplyHarvestVaultImplV1), "SupplyHarvestVaultImplV1");
        vm.label(address(wethSupplyHarvestVault), "SupplyHarvestVault (WETH)");
        vm.label(address(daiSupplyHarvestVault), "SupplyHarvestVault (DAI)");
        vm.label(address(usdcSupplyHarvestVault), "SupplyHarvestVault (USDC)");
        vm.label(address(compSupplyHarvestVault), "SupplyHarvestVault (COMP)");
    }
}
