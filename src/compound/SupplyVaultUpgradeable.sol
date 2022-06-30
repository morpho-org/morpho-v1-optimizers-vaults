// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@contracts/compound/interfaces/compound/ICompound.sol";
import "@contracts/compound/interfaces/IMorpho.sol";

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import "@contracts/compound/libraries/CompoundMath.sol";
import "@contracts/compound/libraries/Types.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../ERC4626UpgradeableSafe.sol";

/// @title SupplyVaultUpgradeable.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault abstract implementation for Morpho-Compound.
abstract contract SupplyVaultUpgradeable is ERC4626UpgradeableSafe, OwnableUpgradeable {
    using SafeTransferLib for ERC20;
    using CompoundMath for uint256;

    /// STORAGE ///

    IMorpho public morpho; // The main Morpho contract.
    ICToken public poolToken; // The pool token corresponding to the market to supply to through this vault.
    IComptroller public comptroller;
    ERC20 public comp;

    /// UPGRADE ///

    /// @dev Initializes the vault.
    /// @param _morphoAddress The address of the main Morpho contract.
    /// @param _poolTokenAddress The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function __SupplyVaultUpgradeable_init(
        address _morphoAddress,
        address _poolTokenAddress,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) internal onlyInitializing returns (bool isEth, address wEth) {
        ERC20 underlyingToken;
        (isEth, wEth, underlyingToken) = __SupplyVaultUpgradeable_init_unchained(
            _morphoAddress,
            _poolTokenAddress
        );

        __Ownable_init();
        __ERC20_init(_name, _symbol);
        __ERC4626UpgradeableSafe_init(ERC20Upgradeable(address(underlyingToken)), _initialDeposit);
    }

    /// @dev Initializes the vault whithout initializing parent contracts (avoid the double initialization problem).
    /// @param _morphoAddress The address of the main Morpho contract.
    /// @param _poolTokenAddress The address of the pool token corresponding to the market to supply through this vault.
    function __SupplyVaultUpgradeable_init_unchained(
        address _morphoAddress,
        address _poolTokenAddress
    )
        internal
        onlyInitializing
        returns (
            bool isEth,
            address wEth,
            ERC20 underlyingToken
        )
    {
        morpho = IMorpho(_morphoAddress);
        poolToken = ICToken(_poolTokenAddress);
        comptroller = morpho.comptroller();
        comp = ERC20(comptroller.getCompAddress());

        isEth = _poolTokenAddress == morpho.cEth();
        wEth = morpho.wEth();

        underlyingToken = ERC20(isEth ? wEth : ICToken(poolToken).underlying());
        underlyingToken.safeApprove(_morphoAddress, type(uint256).max);
    }

    /// PUBLIC ///

    function totalAssets() public view override returns (uint256) {
        address poolTokenAddress = address(poolToken);
        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            poolTokenAddress,
            address(this)
        );

        return
            supplyBalance.onPool.mul(poolToken.exchangeRateStored()) +
            supplyBalance.inP2P.mul(morpho.p2pSupplyIndex(poolTokenAddress));
    }

    /// INTERNAL ///

    function _deposit(
        address _caller,
        address _receiver,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
        super._deposit(_caller, _receiver, _assets, _shares);
        morpho.supply(address(poolToken), address(this), _assets);
    }

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
        morpho.withdraw(address(poolToken), _assets);
        super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    }
}
