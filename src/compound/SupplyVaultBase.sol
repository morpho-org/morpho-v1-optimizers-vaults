// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import {IComptroller, ICToken} from "@contracts/compound/interfaces/compound/ICompound.sol";
import {IMorpho} from "@contracts/compound/interfaces/IMorpho.sol";

import {SafeTransferLib, ERC20} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {CompoundMath} from "@morpho-labs/morpho-utils/math/CompoundMath.sol";
import {Types} from "@contracts/compound/libraries/Types.sol";

import {ERC4626UpgradeableSafe, IERC20MetadataUpgradeable} from "../ERC4626UpgradeableSafe.sol";

/// @title SupplyVaultBase.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault abstract implementation for Morpho-Compound.
contract SupplyVaultBase is ERC4626UpgradeableSafe {
    using SafeTransferLib for ERC20;
    using CompoundMath for uint256;

    /// ERRORS ///

    /// @notice Thrown when the zero address is passed as input.
    error ZeroAddress();

    /// STORAGE ///

    IMorpho public immutable morpho; // The main Morpho contract.
    address public immutable poolToken; // The pool token corresponding to the market to supply to through this vault.
    address public immutable wEth; // The address of WETH token.
    address public immutable comp; // The address of COMP token.

    /// CONSTRUCTOR ///

    /// @notice Constructs the vault.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    constructor(address _morpho, address _poolToken) initializer {
        if (_morpho == address(0) || _poolToken == address(0)) revert ZeroAddress();

        morpho = IMorpho(_morpho);
        poolToken = _poolToken;
        wEth = morpho.wEth();
        comp = morpho.comptroller().getCompAddress();
    }

    /// UPGRADE ///

    /// @dev Initializes the vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function __SupplyVaultBase_init(
        string memory _name,
        string memory _symbol,
        uint256 _initialDeposit
    ) internal onlyInitializing {
        ERC20 underlyingToken = __SupplyVaultBase_init_unchained();

        __ERC20_init(_name, _symbol);
        __ERC4626UpgradeableSafe_init(
            IERC20MetadataUpgradeable(address(underlyingToken)),
            _initialDeposit
        );
    }

    /// @dev Initializes the vault whithout initializing parent contracts (avoid the double initialization problem).
    function __SupplyVaultBase_init_unchained()
        internal
        onlyInitializing
        returns (ERC20 underlyingToken)
    {
        underlyingToken = ERC20(
            poolToken == morpho.cEth() ? wEth : ICToken(poolToken).underlying()
        );

        underlyingToken.safeApprove(address(morpho), type(uint256).max);
    }

    /// PUBLIC ///

    function totalAssets() public view override returns (uint256) {
        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            poolToken,
            address(this)
        );

        return
            supplyBalance.onPool.mul(ICToken(poolToken).exchangeRateStored()) +
            supplyBalance.inP2P.mul(morpho.p2pSupplyIndex(poolToken));
    }

    /// INTERNAL ///

    function _deposit(
        address _caller,
        address _receiver,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
        super._deposit(_caller, _receiver, _assets, _shares);
        morpho.supply(poolToken, address(this), _assets);
    }

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
        morpho.withdraw(poolToken, _assets);
        super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    }
}
