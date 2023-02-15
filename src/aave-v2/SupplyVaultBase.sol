// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import {IERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import {IAToken} from "@contracts/aave-v2/interfaces/aave/IAToken.sol";
import {IMorpho} from "@contracts/aave-v2/interfaces/IMorpho.sol";
import {ILens} from "@contracts/aave-v2/interfaces/ILens.sol";
import {ISupplyVaultBase} from "./interfaces/ISupplyVaultBase.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20, SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {Math} from "@morpho-labs/morpho-utils/math/Math.sol";
import {Types} from "@contracts/aave-v2/libraries/Types.sol";

import {ERC4626UpgradeableSafe, ERC4626Upgradeable, ERC20Upgradeable} from "../ERC4626UpgradeableSafe.sol";

/// @title SupplyVaultBase.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault abstract implementation for Morpho-Aave V2.
abstract contract SupplyVaultBase is ISupplyVaultBase, ERC4626UpgradeableSafe, OwnableUpgradeable {
    using SafeTransferLib for ERC20;

    /// EVENTS ///

    /// @notice Emitted when MORPHO rewards are transferred to `recipient`.
    /// @param recipient The recipient of the rewards.
    /// @param amount The amount of rewards transferred.
    event RewardsTransferred(address recipient, uint256 amount);

    /// ERRORS ///

    /// @notice Thrown when the zero address is passed as input or is the recipient address when calling `transferRewards`.
    error ZeroAddress();

    /// IMMUTABLES ///

    IMorpho public immutable morpho; // The main Morpho contract.
    ERC20 public immutable morphoToken; // The address of the Morpho Token.
    ILens public immutable lens; // The address of the Morpho Lens.
    address public immutable recipient; // The recipient of the rewards that will redistribute them to vault's users.

    /// STORAGE ///

    address public poolToken; // The pool token corresponding to the market to supply to through this vault.

    /// CONSTRUCTOR ///

    /// @dev Initializes network-wide immutables.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _morphoToken The address of the Morpho Token.
    /// @param _lens The address of the Morpho Lens.
    /// @param _recipient The recipient of the rewards that will redistribute them to vault's users.
    constructor(
        address _morpho,
        address _morphoToken,
        address _lens,
        address _recipient
    ) {
        if (
            _morpho == address(0) ||
            _morphoToken == address(0) ||
            _lens == address(0) ||
            _recipient == address(0)
        ) revert ZeroAddress();
        morpho = IMorpho(_morpho);
        morphoToken = ERC20(_morphoToken);
        lens = ILens(_lens);
        recipient = _recipient;
    }

    /// INITIALIZER ///

    /// @dev Initializes the vault.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function __SupplyVaultBase_init(
        address _poolToken,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) internal onlyInitializing {
        ERC20 underlyingToken = __SupplyVaultBase_init_unchained(_poolToken);

        __Ownable_init_unchained();
        __ERC20_init_unchained(_name, _symbol);
        __ERC4626_init_unchained(ERC20Upgradeable(address(underlyingToken)));
        __ERC4626UpgradeableSafe_init_unchained(_initialDeposit);
    }

    /// @dev Initializes the vault whithout initializing parent contracts (avoid the double initialization problem).
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    function __SupplyVaultBase_init_unchained(address _poolToken)
        internal
        onlyInitializing
        returns (ERC20 underlyingToken)
    {
        poolToken = _poolToken;

        underlyingToken = ERC20(IAToken(_poolToken).UNDERLYING_ASSET_ADDRESS()); // Reverts on zero address so no check for pool token needed.
        underlyingToken.safeApprove(address(morpho), type(uint256).max);
    }

    /// EXTERNAL ///

    /// @notice Transfers the MORPHO rewards to the rewards recipient.
    function transferRewards() external {
        uint256 amount = morphoToken.balanceOf(address(this));
        morphoToken.safeTransfer(recipient, amount);
        emit RewardsTransferred(recipient, amount);
    }

    /// PUBLIC ///

    /// @notice The amount of assets in the vault.
    function totalAssets()
        public
        view
        virtual
        override(IERC4626Upgradeable, ERC4626Upgradeable)
        returns (uint256)
    {
        (, , uint256 totalBalance) = lens.getCurrentSupplyBalanceInOf(poolToken, address(this));
        return totalBalance;
    }

    /// @notice Deposits an amount of assets into the vault and receive vault shares.
    /// @param assets The amount of assets to deposit.
    /// @param receiver The recipient of the vault shares.
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override(IERC4626Upgradeable, ERC4626Upgradeable)
        returns (uint256)
    {
        // Update the indexes to get the most up-to-date total assets balance.
        morpho.updateIndexes(poolToken);
        return super.deposit(assets, receiver);
    }

    /// @notice Mints shares of the vault and transfers assets to the vault.
    /// @param shares The number of shares to mint.
    /// @param receiver The recipient of the vault shares.
    function mint(uint256 shares, address receiver)
        public
        virtual
        override(IERC4626Upgradeable, ERC4626Upgradeable)
        returns (uint256)
    {
        // Update the indexes to get the most up-to-date total assets balance.
        morpho.updateIndexes(poolToken);
        return super.mint(shares, receiver);
    }

    /// @notice Withdraws an amount of assets from the vault and burn an owner's shares.
    /// @param assets The number of assets to withdraw.
    /// @param receiver The recipient of the assets.
    /// @param owner The owner of the vault shares.
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override(IERC4626Upgradeable, ERC4626Upgradeable) returns (uint256) {
        // Update the indexes to get the most up-to-date total assets balance.
        morpho.updateIndexes(poolToken);
        return super.withdraw(assets, receiver, owner);
    }

    /// @notice Burn an amount of shares and receive assets.
    /// @param shares The number of shares to burn.
    /// @param receiver The recipient of the assets.
    /// @param owner The owner of the assets.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override(IERC4626Upgradeable, ERC4626Upgradeable) returns (uint256) {
        // Update the indexes to get the most up-to-date total assets balance.
        morpho.updateIndexes(poolToken);
        return super.redeem(shares, receiver, owner);
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

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    uint256[49] private __gap;
}
