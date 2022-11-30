// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/compound/setup/TestSetup.sol";

import {SupplyVaultBase} from "@vaults/compound/SupplyVaultBase.sol";
import {SupplyVault} from "@vaults/compound/SupplyVault.sol";

import "@morpho-labs/morpho-utils/math/PercentageMath.sol";

import "../../helpers/interfaces/IRolesAuthority.sol";
import "../../helpers/FakeToken.sol";
import "../helpers/VaultUser.sol";
import "../helpers/SupplyVaultBaseMock.sol";

contract TestSetupVaults is TestSetup {
    using SafeTransferLib for ERC20;

    address internal constant MORPHO_DAO = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;
    address internal constant MORPHO_TOKEN = 0x9994E35Db50125E0DF82e4c2dde62496CE330999;
    address internal constant LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

    TransparentUpgradeableProxy internal wethSupplyVaultProxy;

    SupplyVault internal supplyVaultImplV1;

    SupplyVault internal wethSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;
    SupplyVaultBase internal supplyVaultBase;

    ERC20 internal mcWeth;
    ERC20 internal mcDai;
    ERC20 internal mcUsdc;

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
        supplyVaultImplV1 = new SupplyVault(address(morpho), MORPHO_TOKEN, LENS);

        supplyVaultBase = SupplyVaultBase(
            address(
                new TransparentUpgradeableProxy(
                    address(new SupplyVaultBaseMock(address(morpho), MORPHO_TOKEN, LENS)),
                    address(proxyAdmin),
                    ""
                )
            )
        );

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
        vm.label(address(daiSupplyVault), "SupplyVault (DAI)");
        vm.label(address(wethSupplyVault), "SupplyVault (WETH)");
        vm.label(address(usdcSupplyVault), "SupplyVault (USDC)");
    }
}
