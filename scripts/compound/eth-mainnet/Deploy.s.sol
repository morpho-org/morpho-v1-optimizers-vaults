// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import "@config/Config.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

import {SupplyVault} from "@vaults/compound/SupplyVault.sol";
import {SupplyHarvestVault} from "@vaults/compound/SupplyHarvestVault.sol";
import {IAdmoDeployer} from "@vaults/interfaces/IAdmoDeployer.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "forge-std/console2.sol";

import {IMorpho} from "@contracts/compound/interfaces/IMorpho.sol";
import {ICToken} from "@contracts/compound/interfaces/compound/ICompound.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Deploy is Script, Config {
    using SafeERC20 for IERC20;

    address public supplyVaultImpl;

    address public constant DEPLOYER = 0xD824b88Dd1FD866B766eF80249E4c2f545a68b7f;
    address public constant MORPHO_DAO = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;
    address public constant PROXY_ADMIN = 0x99917ca0426fbC677e84f873Fb0b726Bb4799cD8;
    address public constant MORPHO = 0x8888882f8f843896699869179fB6E4f7e3B58888;
    address public constant ADMO_DEPLOYER = 0x08072D67a6f158FE2c6f21886B0742736e925536;

    uint256 public constant DEFAULT_INITIAL_DEPOSIT = 1e15;
    uint256 public constant USD_INITIAL_DEPOSIT = 1e8;
    uint256 public constant WBTC_INITIAL_DEPOSIT = 1e6;

    function run() external {
        vm.startBroadcast(DEPLOYER);

        supplyVaultImpl = deploySupplyVaultImplementation();

        deployVaults(cDai, supplyVaultImpl, DEFAULT_INITIAL_DEPOSIT);
        deployVaults(cEth, supplyVaultImpl, DEFAULT_INITIAL_DEPOSIT);
        deployVaults(cComp, supplyVaultImpl, DEFAULT_INITIAL_DEPOSIT);
        deployVaults(cUni, supplyVaultImpl, DEFAULT_INITIAL_DEPOSIT);
        deployVaults(cUsdc, supplyVaultImpl, USD_INITIAL_DEPOSIT);
        deployVaults(cUsdt, supplyVaultImpl, USD_INITIAL_DEPOSIT);
        deployVaults(cWbtc2, supplyVaultImpl, WBTC_INITIAL_DEPOSIT);

        vm.stopBroadcast();
    }

    function deploySupplyVaultImplementation() internal returns (address supplyVaultImpl_) {
        supplyVaultImpl_ = IAdmoDeployer(ADMO_DEPLOYER).performCreate2(
            0,
            abi.encodePacked(type(SupplyVault).creationCode, abi.encode(MORPHO)),
            keccak256(abi.encode("Morpho-Compound Supply Vault Implementation 1.2"))
        );
        console2.log("Deployed Supply Vault Implementation:");
        console2.log(supplyVaultImpl_);
    }

    function deployVaults(
        address _poolToken,
        address _supplyVaultImpl,
        uint256 _initialDeposit
    ) internal returns (address supplyVault_) {
        address cEth = IMorpho(MORPHO).cEth();
        address underlying;

        if (_poolToken == cEth) underlying = IMorpho(MORPHO).wEth();
        else underlying = ICToken(_poolToken).underlying();

        string memory supplyVaultName = string(
            abi.encodePacked("Morpho-Compound ", ERC20(underlying).name(), " Supply Vault")
        );
        string memory supplyVaultSymbol = string(
            abi.encodePacked("mc", ERC20(underlying).symbol())
        );

        supplyVault_ = deploySupplyVaultProxy(
            _supplyVaultImpl,
            _poolToken,
            underlying,
            supplyVaultName,
            supplyVaultSymbol,
            _initialDeposit
        );
    }

    function deploySupplyVaultProxy(
        address _supplyVaultImpl,
        address _poolToken,
        address _underlying,
        string memory _name,
        string memory _symbol,
        uint256 _initialDeposit
    ) internal returns (address supplyVault_) {
        bytes memory creationCode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(_supplyVaultImpl, PROXY_ADMIN, "")
        );
        bytes32 salt = keccak256(
            abi.encode("Morpho Supply Vault v1.1", _poolToken, _name, _symbol)
        );

        supplyVault_ = Create2.computeAddress(salt, keccak256(creationCode), ADMO_DEPLOYER);
        IERC20(_underlying).safeApprove(supplyVault_, _initialDeposit);
        require(
            supplyVault_ == IAdmoDeployer(ADMO_DEPLOYER).performCreate2(0, creationCode, salt),
            "Incorrect precompute address"
        );
        SupplyVault supplyVault = SupplyVault(supplyVault_);

        supplyVault.initialize(_poolToken, _name, _symbol, _initialDeposit);
        console2.log(
            string(
                abi.encodePacked(
                    "Deployed Supply Vault Proxy for ",
                    ERC20(_underlying).symbol(),
                    ":"
                )
            )
        );
        console2.log(supplyVault_);
        require(supplyVault.totalAssets() > 0, "Assets not > 0");
        require(supplyVault.totalSupply() > 0, "Supply not > 0");
    }
}
