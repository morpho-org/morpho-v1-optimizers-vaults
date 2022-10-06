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
import {ERC20, SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

contract Deploy is Script, Config {
    using SafeTransferLib for ERC20;

    address public supplyVaultImpl;
    address public supplyHarvestVaultImpl;

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
        supplyHarvestVaultImpl = deploySupplyHarvestVaultImplementation();

        deployVaults(
            cDai,
            supplyVaultImpl,
            supplyHarvestVaultImpl,
            DEFAULT_INITIAL_DEPOSIT,
            SupplyHarvestVault.HarvestConfig(3000, 500, 200)
        );
        deployVaults(
            cEth,
            supplyVaultImpl,
            supplyHarvestVaultImpl,
            DEFAULT_INITIAL_DEPOSIT,
            SupplyHarvestVault.HarvestConfig(3000, 0, 200)
        );
        deployVaults(
            cComp,
            supplyVaultImpl,
            supplyHarvestVaultImpl,
            DEFAULT_INITIAL_DEPOSIT,
            SupplyHarvestVault.HarvestConfig(3000, 3000, 200)
        );
        deployVaults(
            cUni,
            supplyVaultImpl,
            supplyHarvestVaultImpl,
            DEFAULT_INITIAL_DEPOSIT,
            SupplyHarvestVault.HarvestConfig(3000, 3000, 200)
        );
        deployVaults(
            cUsdc,
            supplyVaultImpl,
            supplyHarvestVaultImpl,
            USD_INITIAL_DEPOSIT,
            SupplyHarvestVault.HarvestConfig(3000, 500, 200)
        );
        deployVaults(
            cUsdt,
            supplyVaultImpl,
            supplyHarvestVaultImpl,
            USD_INITIAL_DEPOSIT,
            SupplyHarvestVault.HarvestConfig(3000, 500, 200)
        );
        deployVaults(
            cWbtc2,
            supplyVaultImpl,
            supplyHarvestVaultImpl,
            WBTC_INITIAL_DEPOSIT,
            SupplyHarvestVault.HarvestConfig(3000, 3000, 200)
        );

        vm.stopBroadcast();
    }

    function deploySupplyVaultImplementation() internal returns (address supplyVaultImpl_) {
        supplyVaultImpl_ = IAdmoDeployer(ADMO_DEPLOYER).performCreate2(
            0,
            abi.encodePacked(type(SupplyVault).creationCode, abi.encode(MORPHO)),
            keccak256(abi.encode("Morpho-Compound Supply Vault Implementation 1.1"))
        );
        console2.log("Deployed Supply Vault Implementation:");
        console2.log(supplyVaultImpl_);
    }

    function deploySupplyHarvestVaultImplementation()
        internal
        returns (address supplyHarvestVaultImpl_)
    {
        supplyHarvestVaultImpl_ = IAdmoDeployer(ADMO_DEPLOYER).performCreate2(
            0,
            abi.encodePacked(type(SupplyHarvestVault).creationCode, abi.encode(MORPHO)),
            keccak256(abi.encode("Morpho-Compound Supply Vault Implementation 1.1"))
        );
        console2.log("Deployed Supply Harvest Vault Implementation:");
        console2.log(supplyHarvestVaultImpl_);
    }

    function deployVaults(
        address _poolToken,
        address _supplyVaultImpl,
        address _supplyHarvestVaultImpl,
        uint256 _initialDeposit,
        SupplyHarvestVault.HarvestConfig memory _harvestConfig
    ) internal returns (address supplyVault_, address supplyHarvestVault_) {
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

        string memory supplyHarvestVaultName = string(
            abi.encodePacked("Morpho-Compound ", ERC20(underlying).name(), " Supply Harvest Vault")
        );
        string memory supplyHarvestVaultSymbol = string(
            abi.encodePacked("mch", ERC20(underlying).symbol())
        );

        supplyVault_ = deploySupplyVaultProxy(
            _supplyVaultImpl,
            _poolToken,
            underlying,
            supplyVaultName,
            supplyVaultSymbol,
            _initialDeposit
        );
        supplyHarvestVault_ = deploySupplyHarvestVaultProxy(
            _supplyHarvestVaultImpl,
            _poolToken,
            underlying,
            supplyHarvestVaultName,
            supplyHarvestVaultSymbol,
            _initialDeposit,
            _harvestConfig
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
        ERC20(_underlying).safeApprove(supplyVault_, _initialDeposit);
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

    function deploySupplyHarvestVaultProxy(
        address _supplyHarvestVaultImpl,
        address _poolToken,
        address _underlying,
        string memory _name,
        string memory _symbol,
        uint256 _initialDeposit,
        SupplyHarvestVault.HarvestConfig memory _harvestConfig
    ) internal returns (address supplyHarvestVault_) {
        bytes memory creationCode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(_supplyHarvestVaultImpl, PROXY_ADMIN, "")
        );
        bytes32 salt = keccak256(
            abi.encode("Morpho Supply Harvest Vault v1.1", _poolToken, _name, _symbol)
        );
        supplyHarvestVault_ = Create2.computeAddress(salt, keccak256(creationCode), ADMO_DEPLOYER);

        require(
            supplyHarvestVault_ ==
                IAdmoDeployer(ADMO_DEPLOYER).performCreate2(0, creationCode, salt),
            "Incorrect precompute address"
        );
        ERC20(_underlying).safeApprove(supplyHarvestVault_, _initialDeposit);
        SupplyHarvestVault supplyHarvestVault = SupplyHarvestVault(supplyHarvestVault_);
        SupplyHarvestVault(supplyHarvestVault_).initialize(
            _poolToken,
            _name,
            _symbol,
            _initialDeposit,
            _harvestConfig
        );
        console2.log(
            string(
                abi.encodePacked(
                    "Deployed Supply Harvest Vault Proxy for ",
                    ERC20(_underlying).symbol(),
                    ":"
                )
            )
        );
        console2.log(supplyHarvestVault_);
        Ownable(supplyHarvestVault_).transferOwnership(MORPHO_DAO);
        require(supplyHarvestVault.totalAssets() > 0, "Assets not > 0");
        require(supplyHarvestVault.totalSupply() > 0, "Supply not > 0");
    }
}
