// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/compound/setup/TestSetup.sol";

import {SupplyVaultBase} from "@vaults/compound/SupplyVaultBase.sol";
import {SupplyVault} from "@vaults/compound/SupplyVault.sol";

import "forge-std/console2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@morpho-labs/morpho-utils/math/PercentageMath.sol";

import "../helpers/VaultUser.sol";

contract TestSetupVaultsLive is TestSetup {
    using SafeTransferLib for ERC20;

    address internal constant SV_IMPL = 0xa43e60F739d3b5AfDDb317A1927fc5bDAc751a57;
    address internal constant SHV_IMPL = 0x301eF488D67d24B2CF4DdbC6771b6feD3Cc4A2a6;
    address internal constant WETH_SV = 0x5C17aA0730030Ca7D0afc2a472bBD1D7E3DdC72d;
    address internal constant DAI_SV = 0xDfe7d9322835EBD7317B5947e898780a2f97B636;
    address internal constant USDC_SV = 0x125e52E814d1f32D64f62677bFFA28225a9283D1;
    address internal constant PROXY_ADMIN = 0x99917ca0426fbC677e84f873Fb0b726Bb4799cD8;
    address internal constant PROXY_ADMIN_OWNER = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;

    address internal constant MORPHO = 0x8888882f8f843896699869179fB6E4f7e3B58888;
    address internal constant LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;
    address internal constant MORPHO_TOKEN = 0x9994E35Db50125E0DF82e4c2dde62496CE330999;
    address internal constant RECIPIENT = 0x60345417a227ad7E312eAa1B5EC5CD1Fe5E2Cdc6;

    TransparentUpgradeableProxy internal wethSupplyVaultProxy;

    SupplyVault internal supplyVaultImplV1;

    SupplyVault internal wethSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;

    ERC20 internal mcWeth;
    ERC20 internal mcDai;
    ERC20 internal mcUsdc;

    VaultUser public vaultSupplier1;
    VaultUser public vaultSupplier2;
    VaultUser public vaultSupplier3;
    VaultUser[] public vaultSuppliers;

    uint256 internal forkId;

    function onSetUp() public override {
        // Fork from latest block
        string memory endpoint = vm.envString("FOUNDRY_ETH_RPC_URL");
        forkId = vm.createFork(endpoint);
        vm.selectFork(forkId);
        initVaultContracts();
        setVaultContractsLabels();
        initVaultUsers();
    }

    function initVaultContracts() internal {
        morpho = Morpho(payable(MORPHO));
        proxyAdmin = ProxyAdmin(PROXY_ADMIN);
        lens = Lens(LENS);

        supplyVaultImplV1 = SupplyVault(SV_IMPL);

        wethSupplyVaultProxy = TransparentUpgradeableProxy(payable(WETH_SV));

        wethSupplyVault = SupplyVault(WETH_SV);
        daiSupplyVault = SupplyVault(DAI_SV);
        usdcSupplyVault = SupplyVault(USDC_SV);

        mcWeth = ERC20(WETH_SV);
        mcDai = ERC20(DAI_SV);
        mcUsdc = ERC20(USDC_SV);
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
        vm.label(address(supplyVaultImplV1), "SupplyVaultImplV1");
        vm.label(address(wethSupplyVault), "SupplyVault (WETH)");
        vm.label(address(daiSupplyVault), "SupplyVault (DAI)");
        vm.label(address(usdcSupplyVault), "SupplyVault (USDC)");
    }
}
