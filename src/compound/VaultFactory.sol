// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import {ICToken} from "@contracts/compound/interfaces/compound/ICompound.sol";
import {IMorpho} from "@contracts/compound/interfaces/IMorpho.sol";

import {Bytes32AddressLib} from "@rari-capital/solmate/src/utils/Bytes32AddressLib.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {SupplyHarvestVault} from "./SupplyHarvestVault.sol";
import {SupplyVault} from "./SupplyVault.sol";

contract VaultFactory is Ownable {
    using Bytes32AddressLib for address;
    using Bytes32AddressLib for bytes32;

    event VaultImplementationDeployed(Vault vault);

    enum VaultVersion {
        SupplyVault,
        SupplyHarvestVault
    }

    function deployVaultImplementation(VaultVersion _vaultVersion)
        external
        onlyOwner
        returns (address vault)
    {
        if (_vaultVersion == VaultVersion.SupplyVault) vault = new SupplyVault();
        else vault = SupplyHarvestVault();

        emit VaultImplementationDeployed(vault);
    }

    function createSupplyVault(
        address _implementation,
        address _proxyAdmin,
        address _morpho,
        address _poolToken,
        uint256 _initialDeposit
    ) external onlyOwner returns (address vault) {
        address cEth = IMorpho(morpho).cEth();
        address underlying;

        if (_poolToken == cEth) underlying = IMorpho(morpho).wEth();
        else underlying = ICToken(_poolToken);

        string name = string(abi.encodePacked("Morpho-Compound ", underlying.name(), " Supply Vault"));
        string symbol = string(abi.encodePacked("mc", underlying.symbol()));

        vault = new TransparentUpgradeableProxy{salt: underlying.fillLast12Bytes()}(
            _implementation,
            _proxyAdmin,
            abi.encodeWithSelector(SupplyVault.initialize.selector, _morpho, _poolToken, name, symbol, _initialDeposit);
        );
    }

    function createSupplyHarvestVault(
        address _implementation,
        address _proxyAdmin,
        address _morpho,
        address _poolToken,
        uint256 _initialDeposit,
        SupplyHarvestVault.HarvestConfig _config
    ) external onlyOwner returns (address vault) {
        address cEth = IMorpho(morpho).cEth();
        address underlying;

        if (_poolToken == cEth) underlying = IMorpho(morpho).wEth();
        else underlying = ICToken(_poolToken);

        string name = string(abi.encodePacked("Morpho-Compound ", underlying.name(), " Supply Harvest Vault"));
        string symbol = string(abi.encodePacked("mch", underlying.symbol()));

        vault = new TransparentUpgradeableProxy{salt: underlying.fillLast12Bytes()}(
            _implementation,
            _proxyAdmin,
            abi.encodeWithSelector(SupplyVault.initialize.selector, _morpho, _poolToken, name, symbol, _initialDeposit, _config);
        );
    }

    function getVaultAddress(address _implementation, address _proxyAdmin, ERC20 _underlying) external view returns (address) {
        return
            address(
                keccak256(
                    abi.encodePacked(
                        // Prefix:
                        bytes1(0xFF),
                        // Creator:
                        address(this),
                        // Salt:
                        address(underlying).fillLast12Bytes(),
                        // Bytecode hash:
                        keccak256(
                            abi.encodePacked(
                                // Deployment bytecode:
                                type(TransparentUpgradeableProxy).creationCode,
                                // Constructor arguments:
                                abi.encode(_implementation, _proxyAdmin)
                            )
                        )
                    )
                ).fromLast20Bytes()  // Convert the CREATE2 hash into an address
            );
    }

    function isVaultDeployed(address _vault) external view returns (bool) {
        return _vault.code.length > 0;
    }
}
