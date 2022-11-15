// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/aave-v2/setup/TestSetup.sol";

import {SupplyVaultBase} from "@vaults/aave-v2/SupplyVaultBase.sol";
import {SupplyVault} from "@vaults/aave-v2/SupplyVault.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../helpers/VaultUser.sol";

contract TestSetupVaultsLive is TestSetup {
    using SafeTransferLib for ERC20;
    TransparentUpgradeableProxy internal wNativeSupplyVaultProxy;

    SupplyVault internal supplyVaultImplV1;

    address internal constant W_NATIVE_VAULT_ADDRESS = 0x762fafA0257CD3b697e0D7FD40f1f6c03F07A8ef;
    address internal constant DAI_VAULT_ADDRESS = 0x3A91D37BAc30C913369E1ABC8CAd1C13D1ff2e98;
    address internal constant USDC_VAULT_ADDRESS = 0xd45EF8c9b9431298019FC15753609DB2FB101aa5;
    address internal constant MORPHO_TOKEN = 0x9994E35Db50125E0DF82e4c2dde62496CE330999;

    uint256 internal constant INITIAL_DEPOSIT = 1e8;

    address internal constant PROXY_ADMIN_OWNER = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;

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

    uint256 internal forkId;

    function onSetUp() public override {
        // Fork from latest block
        string memory endpoint = vm.envString("FOUNDRY_ETH_RPC_URL");
        forkId = vm.createFork(endpoint);
        vm.selectFork(forkId);
        initVaultContracts();
        initVaultUsers();
    }

    function initVaultContracts() internal {
        morpho = Morpho(0x777777c9898D384F785Ee44Acfe945efDFf5f3E0);
        wNativeSupplyVault = SupplyVault(W_NATIVE_VAULT_ADDRESS);
        daiSupplyVault = SupplyVault(DAI_VAULT_ADDRESS);
        usdcSupplyVault = SupplyVault(USDC_VAULT_ADDRESS);

        ma2WNative = ERC20(W_NATIVE_VAULT_ADDRESS);
        ma2Dai = ERC20(DAI_VAULT_ADDRESS);
        ma2Usdc = ERC20(USDC_VAULT_ADDRESS);

        proxyAdmin = ProxyAdmin(0x99917ca0426fbC677e84f873Fb0b726Bb4799cD8);

        wNativeSupplyVaultProxy = TransparentUpgradeableProxy(payable(W_NATIVE_VAULT_ADDRESS));
        supplyVaultImplV1 = SupplyVault(0x65663ee4cC7c9C494802e7f10cbBd710d3F1FE95);
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
