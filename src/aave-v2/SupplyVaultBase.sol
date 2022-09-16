// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import {ILendingPool} from "@contracts/aave-v2/interfaces/aave/ILendingPool.sol";
import {IAToken} from "@contracts/aave-v2/interfaces/aave/IAToken.sol";
import {IMorpho} from "@contracts/aave-v2/interfaces/IMorpho.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WadRayMath} from "@morpho-labs/morpho-utils/math/WadRayMath.sol";
import {Math} from "@morpho-labs/morpho-utils/math/Math.sol";
import {Types} from "@contracts/aave-v2/libraries/Types.sol";

import {ERC4626UpgradeableSafe, ERC20Upgradeable} from "../ERC4626UpgradeableSafe.sol";

/// @title SupplyVaultBase.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault abstract implementation for Morpho-Aave V2.
abstract contract SupplyVaultBase is ERC4626UpgradeableSafe {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    /// ERRORS ///

    /// @notice Thrown when the zero address is passed as input.
    error ZeroAddress();

    /// STORAGE ///

    IMorpho public immutable morpho; // The main Morpho contract.
    ILendingPool public immutable pool;
    address public poolToken; // The pool token corresponding to the market to supply to through this vault.

    /// @dev Initializes network-wide immutables
    /// @param _morpho The address of the main Morpho contract.
    constructor(address _morpho) {
        if (_morpho == address(0)) revert ZeroAddress();

        morpho = IMorpho(_morpho);
        pool = morpho.pool();
    }

    /// UPGRADE ///

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
        IERC20 underlyingToken = __SupplyVaultBase_init_unchained(_poolToken);

        __ERC20_init(_name, _symbol);
        __ERC4626UpgradeableSafe_init(ERC20Upgradeable(address(underlyingToken)), _initialDeposit);
    }

    /// @dev Initializes the vault whithout initializing parent contracts (avoid the double initialization problem).
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    function __SupplyVaultBase_init_unchained(address _poolToken)
        internal
        onlyInitializing
        returns (IERC20 underlyingToken)
    {
        if (_poolToken == address(0)) revert ZeroAddress();

        poolToken = _poolToken;

        underlyingToken = IERC20(IAToken(_poolToken).UNDERLYING_ASSET_ADDRESS());
        underlyingToken.safeApprove(address(morpho), type(uint256).max);
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
