// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/compound/setup/TestSetup.sol";

import {SupplyVaultBase} from "@vaults/compound/SupplyVaultBase.sol";
import {SupplyHarvestVault} from "@vaults/compound/SupplyHarvestVault.sol";
import {SupplyVault} from "@vaults/compound/SupplyVault.sol";

import "@forge-std/console2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@morpho-labs/morpho-utils/math/PercentageMath.sol";

import "../helpers/VaultUser.sol";

contract TestSetupVaultsLive is TestSetup {
    using SafeTransferLib for ERC20;

    address internal constant SV_IMPL = 0xa43e60F739d3b5AfDDb317A1927fc5bDAc751a57;
    address internal constant SHV_IMPL = 0x301eF488D67d24B2CF4DdbC6771b6feD3Cc4A2a6;
    address internal constant WETH_SV = 0x5C17aA0730030Ca7D0afc2a472bBD1D7E3DdC72d;
    address internal constant WETH_SHV = 0x51BD0aCA7Bf4C3b4927c794Bee338465F3885408;
    address internal constant DAI_SV = 0xDfe7d9322835EBD7317B5947e898780a2f97B636;
    address internal constant DAI_SHV = 0xD9B7a4401D4e430aD8b268D72C907a5C7516317f;
    address internal constant USDC_SV = 0x125e52E814d1f32D64f62677bFFA28225a9283D1;
    address internal constant USDC_SHV = 0xAf7DDc2E19248fE4E400aBC052162F146791745F;
    address internal constant COMP_SHV = 0x901579C24e0ECFdb41C4B184b2EE3730975B4Ad5;
    address internal constant PROXY_ADMIN = 0x99917ca0426fbC677e84f873Fb0b726Bb4799cD8;
    address internal constant PROXY_ADMIN_OWNER = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;

    address internal constant MORPHO = 0x8888882f8f843896699869179fB6E4f7e3B58888;
    address internal constant LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

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

    uint256 forkId;

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
        supplyHarvestVaultImplV1 = SupplyHarvestVault(SHV_IMPL);

        wethSupplyVaultProxy = TransparentUpgradeableProxy(payable(WETH_SV));
        wethSupplyHarvestVaultProxy = TransparentUpgradeableProxy(payable(WETH_SHV));

        wethSupplyVault = SupplyVault(WETH_SV);
        daiSupplyVault = SupplyVault(DAI_SV);
        usdcSupplyVault = SupplyVault(USDC_SV);

        wethSupplyHarvestVault = SupplyHarvestVault(WETH_SHV);
        daiSupplyHarvestVault = SupplyHarvestVault(DAI_SHV);
        usdcSupplyHarvestVault = SupplyHarvestVault(USDC_SHV);
        compSupplyHarvestVault = SupplyHarvestVault(COMP_SHV);

        mcWeth = ERC20(WETH_SV);
        mcDai = ERC20(DAI_SV);
        mcUsdc = ERC20(USDC_SV);

        mchWeth = ERC20(WETH_SHV);
        mchDai = ERC20(DAI_SHV);
        mchUsdc = ERC20(USDC_SHV);
        mchComp = ERC20(COMP_SHV);
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
        vm.label(address(supplyVaultImplV1), "SupplyVaultImplV1");
        vm.label(address(wethSupplyVault), "SupplyVault (WETH)");
        vm.label(address(daiSupplyVault), "SupplyVault (DAI)");
        vm.label(address(usdcSupplyVault), "SupplyVault (USDC)");
    }
}
