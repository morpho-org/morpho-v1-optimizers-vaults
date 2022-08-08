// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.10;

import {IAToken} from "@aave/core-v3/contracts/interfaces/IAToken.sol";
import {IPool} from "@contracts/aave-v3/interfaces/aave/IPool.sol";
import {IMorpho} from "@contracts/aave-v3/interfaces/IMorpho.sol";
import {IRewardsController} from "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";

import {ERC20, SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";
import "@morpho-labs/morpho-utils/math/Math.sol";
import "@contracts/aave-v3/libraries/Types.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../ERC4626UpgradeableSafe.sol";

/// @title SupplyVaultUpgradeable.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault abstract implementation for Morpho-Aave V3.
abstract contract SupplyVaultUpgradeable is ERC4626UpgradeableSafe, OwnableUpgradeable {
    using SafeTransferLib for ERC20;
    using WadRayMath for uint256;

    /// ERRORS ///

    /// @notice Thrown when the zero address is passed as input.
    error ZeroAddress();

    /// STORAGE ///

    IMorpho public morpho; // The main Morpho contract.
    address public poolToken; // The pool token corresponding to the market to supply to through this vault.
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
        if (_morpho == address(0) || _poolToken == address(0)) revert ZeroAddress();

        morpho = IMorpho(_morpho);
        poolToken = _poolToken;
        pool = morpho.pool();

        underlyingToken = ERC20(IAToken(poolToken).UNDERLYING_ASSET_ADDRESS());
        underlyingToken.safeApprove(_morpho, type(uint256).max);
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
