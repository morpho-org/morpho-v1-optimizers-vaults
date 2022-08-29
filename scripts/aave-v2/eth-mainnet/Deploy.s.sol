// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import "@config/Config.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {SupplyVault} from "@vaults/aave-v2/SupplyVault.sol";
import {SupplyHarvestVault, OwnableUpgradeable} from "@vaults/aave-v2/SupplyHarvestVault.sol";
import {IAdmoDeployer} from "@vaults/interfaces/IAdmoDeployer.sol";

import "forge-std/console2.sol";

import {IMorpho} from "@contracts/aave-v2/interfaces/IMorpho.sol";
import {IAToken} from "@contracts/aave-v2/interfaces/aave/IAToken.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Deploy is Script, Config {
    using SafeERC20 for IERC20;

    address constant deployer = 0xD824b88Dd1FD866B766eF80249E4c2f545a68b7f;
    address constant safe = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;
    address constant proxyAdmin = 0x99917ca0426fbC677e84f873Fb0b726Bb4799cD8;
    address constant morpho = 0x777777c9898D384F785Ee44Acfe945efDFf5f3E0;
    address constant DAO_OWNER = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;
    address constant ADMO_DEPLOYER = 0x08072D67a6f158FE2c6f21886B0742736e925536;

    uint256 constant DEFAULT_INITIAL_DEPOSIT = 5e7;
    uint256 constant WBTC_INITIAL_DEPOSIT = 5e5;

    function run() external {
        vm.startBroadcast(deployer);

        address supplyVaultImpl = deploySupplyVaultImplementation();
        address supplyHarvestVaultImpl = deploySupplyHarvestVaultImplementation();
        deployVaults(aDai, supplyVaultImpl, supplyHarvestVaultImpl, DEFAULT_INITIAL_DEPOSIT);

        vm.stopBroadcast();
    }

    function deploySupplyVaultImplementation() internal returns (address supplyVaultImpl) {
        supplyVaultImpl = IAdmoDeployer(ADMO_DEPLOYER).performCreate2(
            0,
            type(SupplyVault).creationCode,
            keccak256(abi.encode("Morpho Aave V2 Supply Vault Implementation 1.0"))
        );
        console2.log("Deployed Supply Vault Implementation:");
        console2.log(supplyVaultImpl);
    }

    function deploySupplyHarvestVaultImplementation()
        internal
        returns (address supplyHarvestVaultImpl)
    {
        supplyHarvestVaultImpl = IAdmoDeployer(ADMO_DEPLOYER).performCreate2(
            0,
            type(SupplyHarvestVault).creationCode,
            keccak256(abi.encode("Morpho Aave V2 Supply Harvest Vault Implementation 1.0"))
        );
        console2.log("Deployed Supply Harvest Vault Implementation:");
        console2.log(supplyHarvestVaultImpl);
    }

    function deployVaults(
        address _poolToken,
        address _supplyVaultImpl,
        address _supplyHarvestVaultImpl,
        uint256 _initialDeposit
    ) internal returns (address supplyVault_, address supplyHarvestVault_) {
        address underlying;

        underlying = IAToken(_poolToken).UNDERLYING_ASSET_ADDRESS();

        string memory supplyVaultName = string(
            abi.encodePacked("Morpho-AaveV2 ", ERC20(underlying).name(), " Supply Vault")
        );
        string memory supplyVaultSymbol = string(
            abi.encodePacked("ma2", ERC20(underlying).symbol())
        );

        string memory supplyHarvestVaultName = string(
            abi.encodePacked("Morpho-AaveV2 ", ERC20(underlying).name(), " Supply Harvest Vault")
        );
        string memory supplyHarvestVaultSymbol = string(
            abi.encodePacked("ma2h", ERC20(underlying).symbol())
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
            abi.encode(_supplyVaultImpl, proxyAdmin, "")
        );
        bytes32 salt = keccak256(abi.encode("Morpho Supply Vault", _poolToken, _name, _symbol));

        supplyVault_ = computeAddress(salt, keccak256(creationCode), ADMO_DEPLOYER);
        IERC20(_underlying).safeApprove(supplyVault_, _initialDeposit);
        require(
            supplyVault_ == IAdmoDeployer(ADMO_DEPLOYER).performCreate2(0, creationCode, salt),
            "Incorrect precompute address"
        );

        SupplyVault(supplyVault_).initialize(morpho, _poolToken, _name, _symbol, _initialDeposit);
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
    }

    function deploySupplyHarvestVaultProxy(
        address _supplyHarvestVaultImpl,
        address _poolToken,
        address _underlying,
        string memory _name,
        string memory _symbol,
        uint256 _initialDeposit
    ) internal returns (address supplyHarvestVault_) {
        bytes memory creationCode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(_supplyHarvestVaultImpl, proxyAdmin, "")
        );
        bytes32 salt = keccak256(
            abi.encode("Morpho Supply Harvest Vault", _poolToken, _name, _symbol)
        );
        supplyHarvestVault_ = computeAddress(salt, keccak256(creationCode), ADMO_DEPLOYER);

        require(
            supplyHarvestVault_ ==
                IAdmoDeployer(ADMO_DEPLOYER).performCreate2(0, creationCode, salt),
            "Incorrect precompute address"
        );
        IERC20(_underlying).safeApprove(supplyHarvestVault_, _initialDeposit);
        SupplyHarvestVault(supplyHarvestVault_).initialize(
            morpho,
            _poolToken,
            _name,
            _symbol,
            _initialDeposit,
            3000, // TODO: Set harvesting fee
            address(0) // TODO: Set swapper
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
        Ownable(supplyHarvestVault_).transferOwnership(DAO_OWNER);
    }

    function computeAddress(
        bytes32 _salt,
        bytes32 _bytecodeHash,
        address _deployer
    ) internal pure returns (address addr) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40) // Get free memory pointer

            // |                   | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
            // |-------------------|---------------------------------------------------------------------------|
            // | bytecodeHash      |                                                        CCCCCCCCCCCCC...CC |
            // | salt              |                                      BBBBBBBBBBBBB...BB                   |
            // | deployer          | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
            // | 0xFF              |            FF                                                             |
            // |-------------------|---------------------------------------------------------------------------|
            // | memory            | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
            // | keccak(start, 85) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |

            mstore(add(ptr, 0x40), _bytecodeHash)
            mstore(add(ptr, 0x20), _salt)
            mstore(ptr, _deployer) // Right-aligned with 12 preceding garbage bytes
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
    }
}
