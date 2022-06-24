// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@morpho-contracts/contracts/compound/libraries/Types.sol";

import "@vaults/compound/SupplyVault.sol";
import "@vaults/compound/SupplyHarvestVault.sol";

import {User} from "../helpers/User.sol";
import "@config/Config.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract TestSetup is Config, Test {
    uint256 public constant INITIAL_BALANCE = 10_000_000;

    ProxyAdmin public proxyAdmin;
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

    ERC20 mcWeth;
    ERC20 mcDai;
    ERC20 mcUsdc;
    ERC20 mchWeth;
    ERC20 mchDai;
    ERC20 mchUsdc;

    User public supplier1;
    User public supplier2;
    User public supplier3;
    User[] public suppliers;
    User public borrower1;
    User public borrower2;
    User public borrower3;
    User[] public borrowers;

    address[] public pools;

    function setUp() public {
        initContracts();
        setContractsLabels();
        initUsers();
    }

    function initContracts() internal {
        proxyAdmin = new ProxyAdmin();

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
            address(cEth),
            "MorphoCompoundHarvestWETH",
            "mchWETH",
            0,
            3000,
            0,
            50,
            100,
            address(cComp)
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
            address(morpho),
            address(cDai),
            "MorphoCompoundHarvestDAI",
            "mchDAI",
            0,
            3000,
            500,
            50,
            100,
            address(cComp)
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
            address(morpho),
            address(cUsdc),
            "MorphoCompoundHarvestUSDC",
            "mchUSDC",
            0,
            3000,
            500,
            50,
            100,
            address(cComp)
        );
        mchUsdc = ERC20(address(usdcSupplyHarvestVault));

        wethSupplyVaultProxy = new TransparentUpgradeableProxy(
            address(supplyVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wethSupplyVault = SupplyVault(address(wethSupplyVaultProxy));
        wethSupplyVault.initialize(
            address(morpho),
            address(cEth),
            "MorphoCompoundWETH",
            "mcWETH",
            0
        );
        mcWeth = ERC20(address(wethSupplyVault));

        daiSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        daiSupplyVault.initialize(address(morpho), address(cDai), "MorphoCompoundDAI", "mcDAI", 0);
        mcDai = ERC20(address(daiSupplyVault));

        usdcSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        usdcSupplyVault.initialize(
            address(morpho),
            address(cUsdc),
            "MorphoCompoundUSDC",
            "mcUSDC",
            0
        );
        mcUsdc = ERC20(address(usdcSupplyVault));
    }

    function initUsers() internal {
        for (uint256 i = 0; i < 3; i++) {
            suppliers.push(new User(morpho));
            vm.label(
                address(suppliers[i]),
                string(abi.encodePacked("Supplier", Strings.toString(i + 1)))
            );
            fillUserBalances(suppliers[i]);
        }
        supplier1 = suppliers[0];
        supplier2 = suppliers[1];
        supplier3 = suppliers[2];

        for (uint256 i = 0; i < 3; i++) {
            borrowers.push(new User(morpho));
            vm.label(
                address(borrowers[i]),
                string(abi.encodePacked("Borrower", Strings.toString(i + 1)))
            );
            fillUserBalances(borrowers[i]);
        }

        borrower1 = borrowers[0];
        borrower2 = borrowers[1];
        borrower3 = borrowers[2];
    }

    function fillUserBalances(User _user) internal {
        deal(address(dai), address(_user), INITIAL_BALANCE * 1e18);
        deal(address(weth), address(_user), INITIAL_BALANCE * 1e18);
        deal(address(usdt), address(_user), INITIAL_BALANCE * 1e6);
        deal(address(usdc), address(_user), INITIAL_BALANCE * 1e6);
    }

    function setContractsLabels() internal {
        vm.label(address(proxyAdmin), "ProxyAdmin");
        vm.label(address(morpho), "Morpho");
        vm.label(address(comptroller), "Comptroller");
        vm.label(address(lens), "Lens");
        vm.label(address(supplyHarvestVaultImplV1), "SupplyHarvestVaultImplV1");
        vm.label(address(wethSupplyHarvestVault), "SupplyHarvestVault (WETH)");
        vm.label(address(daiSupplyHarvestVault), "SupplyHarvestVault (DAI)");
        vm.label(address(usdcSupplyHarvestVault), "SupplyHarvestVault (USDC)");
    }

    function bytes32ToAddress(bytes32 _bytes) internal pure returns (address) {
        return address(uint160(uint256(_bytes)));
    }
}
