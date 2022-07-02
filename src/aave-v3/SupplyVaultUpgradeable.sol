// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@aave/core-v3/contracts/interfaces/IAToken.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@contracts/aave-v3/interfaces/IMorpho.sol";

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";
import "@contracts/aave-v3/libraries/Types.sol";
import "@contracts/aave-v3/libraries/Math.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../ERC4626UpgradeableSafe.sol";

/// @title SupplyVaultUpgradeable.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault abstract implementation for Morpho-Aave V3.
abstract contract SupplyVaultUpgradeable is ERC4626UpgradeableSafe, OwnableUpgradeable {
    using SafeTransferLib for ERC20;
    using WadRayMath for uint256;

    /// EVENTS ///

    /// @notice Emitted when the address of the `rewardsController` is set.
    /// @param _rewardsController The new address of the `rewardsController`.
    event RewardsControllerSet(address indexed _rewardsController);

    /// STORAGE ///

    IMorpho public morpho; // The main Morpho contract.
    address public poolToken; // The pool token corresponding to the market to supply to through this vault.
    IRewardsController public rewardsController;
    IPool public pool;

    /// UPGRADE ///

    /// @dev Initializes the vault.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function __SupplyVaultUpgradeable_init(
        address _morpho,
        address _poolToken,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) internal onlyInitializing {
        ERC20 underlyingToken = __SupplyVaultUpgradeable_init_unchained(_morpho, _poolToken);

        __Ownable_init();
        __ERC20_init(_name, _symbol);
        __ERC4626UpgradeableSafe_init(ERC20Upgradeable(address(underlyingToken)), _initialDeposit);
    }

    /// @dev Initializes the vault whithout initializing parent contracts (avoid the double initialization problem).
    /// @param _morpho The address of the main Morpho contract.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    function __SupplyVaultUpgradeable_init_unchained(address _morpho, address _poolToken)
        internal
        onlyInitializing
        returns (ERC20 underlyingToken)
    {
        morpho = IMorpho(_morpho);
        poolToken = _poolToken;
        rewardsController = morpho.rewardsController();
        pool = morpho.pool();

        underlyingToken = ERC20(IAToken(poolToken).UNDERLYING_ASSET_ADDRESS());
        underlyingToken.safeApprove(_morpho, type(uint256).max);
    }

    /// GOVERNANCE ///

    /// @notice Sets the `rewardsController`.
    /// @param _rewardsController The address of the new `rewardsController`.
    function setRewardsController(address _rewardsController) external onlyOwner {
        rewardsController = IRewardsController(_rewardsController);
        emit RewardsControllerSet(_rewardsController);
    }

    /// PUBLIC ///

    function totalAssets() public view override returns (uint256) {
        address poolTokenMem = poolToken;
        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            poolTokenMem,
            address(this)
        );

        return
            supplyBalance.onPool.rayMul(pool.getReserveNormalizedIncome(asset())) +
            supplyBalance.inP2P.rayMul(morpho.p2pSupplyIndex(poolTokenMem));
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
