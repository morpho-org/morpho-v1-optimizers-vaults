// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/aave-v2/setup/TestSetup.sol";

import {SupplyVaultBase} from "@vaults/aave-v2/SupplyVaultBase.sol";
import {SupplyHarvestVault} from "@vaults/aave-v2/SupplyHarvestVault.sol";
import {SupplyVault} from "@vaults/aave-v2/SupplyVault.sol";

import "@morpho-labs/morpho-utils/math/PercentageMath.sol";
import "@vaults/UniswapV2Swapper.sol";

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
    SupplyHarvestVault internal aaveSupplyHarvestVault;

    ERC20 ma2Weth;
    ERC20 ma2Dai;
    ERC20 ma2Usdc;
    ERC20 ma2hWeth;
    ERC20 ma2hDai;
    ERC20 ma2hUsdc;
    ERC20 ma2hAave;
    address stkAave;

    ISwapper internal swapper;

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
        stkAave = morpho.aaveIncentivesController().REWARD_TOKEN();
        if (block.chainid == Chains.ETH_MAINNET) {
            swapper = new UniswapV2Swapper(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, wEth);
            vm.label(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, "Uniswap V2");
            vm.label(address(swapper), "Swapper");
        }
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
            "MorphoCompoundHarvestWETH",
            "mchWETH",
            0,
            100,
            address(swapper)
        );
        ma2hWeth = ERC20(address(wethSupplyHarvestVault));

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
            "MorphoCompoundHarvestDAI",
            "ma2hDAI",
            0,
            100,
            address(swapper)
        );
        ma2hDai = ERC20(address(daiSupplyHarvestVault));

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
            address(morpho),
            aUsdc,
            "MorphoCompoundHarvestUSDC",
            "ma2hUSDC",
            0,
            100,
            address(swapper)
        );
        ma2hUsdc = ERC20(address(usdcSupplyHarvestVault));

        aaveSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        aaveSupplyHarvestVault.initialize(
            address(morpho),
            aAave,
            "MorphoAave2HarvestAAVE",
            "ma2hAAVE",
            0,
            100,
            address(swapper)
        );
        ma2hAave = ERC20(address(aaveSupplyHarvestVault));

        wethSupplyVaultProxy = new TransparentUpgradeableProxy(
            address(supplyVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wethSupplyVault = SupplyVault(address(wethSupplyVaultProxy));
        wethSupplyVault.initialize(address(morpho), aWeth, "MorphoAave2WETH", "ma2WETH", 0);
        ma2Weth = ERC20(address(wethSupplyVault));

        daiSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        daiSupplyVault.initialize(address(morpho), address(aDai), "MorphoAave2DAI", "ma2DAI", 0);
        ma2Dai = ERC20(address(daiSupplyVault));

        usdcSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        usdcSupplyVault.initialize(
            address(morpho),
            address(aUsdc),
            "MorphoAave2USDC",
            "ma2USDC",
            0
        );
        ma2hUsdc = ERC20(address(usdcSupplyVault));
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
        vm.label(address(aaveSupplyHarvestVault), "SupplyHarvestVault (AAVE)");
    }
}
