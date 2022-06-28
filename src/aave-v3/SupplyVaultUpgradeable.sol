// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@aave/core-v3/contracts/interfaces/IAToken.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@contracts/aave-v3/interfaces/IMorpho.sol";

import "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";
import "@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol";
import "@contracts/aave-v3/libraries/Math.sol";
import "@contracts/aave-v3/libraries/Types.sol";

import "../ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title SupplyVaultUpgradeable.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable tokenized Vault abstract implementation for Morpho-Aave V3.
abstract contract SupplyVaultUpgradeable is ERC4626Upgradeable, OwnableUpgradeable {
    using SafeTransferLib for ERC20;
    using WadRayMath for uint256;

    /// EVENTS ///

    /// @notice Emitted when the address of the `rewardsController` is set.
    /// @param _rewardsController The new address of the `rewardsController`.
    event RewardsControllerSet(address indexed _rewardsController);

    /// STORAGE ///

    IMorpho public morpho; // The main Morpho contract.
    IAToken public poolToken; // The pool token corresponding to the market to supply to through this vault.
    IRewardsController public rewardsController;
    IPool public pool;

    address public wrappedNativeToken;

    /// UPGRADE ///

    /// @notice Initializes the vault.
    /// @param _morphoAddress The address of the main Morpho contract.
    /// @param _poolTokenAddress The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function __SupplyVault_init(
        address _morphoAddress,
        address _poolTokenAddress,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) internal onlyInitializing {
        __SupplyVault_init_unchained(_morphoAddress, _poolTokenAddress);

        __Ownable_init();
        __ERC4626_init(
            ERC20(poolToken.UNDERLYING_ASSET_ADDRESS()),
            _name,
            _symbol,
            _initialDeposit
        );
    }

    /// @notice Initializes the vault.
    /// @param _morphoAddress The address of the main Morpho contract.
    /// @param _poolTokenAddress The address of the pool token corresponding to the market to supply through this vault.
    function __SupplyVault_init_unchained(address _morphoAddress, address _poolTokenAddress)
        internal
        onlyInitializing
    {
        morpho = IMorpho(_morphoAddress);
        poolToken = IAToken(_poolTokenAddress);
        rewardsController = morpho.rewardsController();
        pool = morpho.pool();

        ERC20(IAToken(_poolTokenAddress).UNDERLYING_ASSET_ADDRESS()).safeApprove(
            _morphoAddress,
            type(uint256).max
        );
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
        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(
            address(poolToken),
            address(this)
        );

        return
            supplyBalance.onPool.rayMul(
                pool.getReserveNormalizedIncome(poolToken.UNDERLYING_ASSET_ADDRESS())
            ) + supplyBalance.inP2P.rayMul(morpho.p2pSupplyIndex(address(poolToken)));
    }

    /// INTERNAL ///

    function _beforeWithdraw(
        address,
        uint256 _amount,
        uint256
    ) internal override {
        morpho.withdraw(address(poolToken), _amount);
    }

    function _afterDeposit(
        address,
        uint256 _amount,
        uint256
    ) internal override {
        morpho.supply(address(poolToken), address(this), _amount);
    }
}
