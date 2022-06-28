// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "./SupplyVaultUpgradeable.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable tokenized Vault implementation for Morpho-Compound, which can harvest accrued COMP rewards, swap them and re-supply them through Morpho-Compound.
contract SupplyVault is SupplyVaultUpgradeable {
    using SafeTransferLib for ERC20;
    using CompoundMath for uint256;

    /// STORAGE ///

    mapping(address => uint256) public userUnclaimedCompRewards; // The unclaimed rewards of the user.
    mapping(address => uint256) public compRewardsIndex; // The comp rewards index of the user.

    /// UPGRADE ///

    /// @notice Initializes the vault.
    /// @param _morphoAddress The address of the main Morpho contract.
    /// @param _poolTokenAddress The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function initialize(
        address _morphoAddress,
        address _poolTokenAddress,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) external initializer {
        __SupplyVault_init(_morphoAddress, _poolTokenAddress, _name, _symbol, _initialDeposit);
    }

    /// EXTERNAL ///

    /// @notice Claims rewards from the underlying pool, swaps them for the underlying asset and supply them through Morpho.
    /// @return rewardsAmount The amount of rewards claimed, swapped then supplied through Morpho (in underlying).
    function claimRewards(address _user) external returns (uint256 rewardsAmount) {
        _accrueUserUnclaimedRewards(_user);

        rewardsAmount = userUnclaimedCompRewards[_user];
        if (rewardsAmount > 0) {
            userUnclaimedCompRewards[_user] = 0;

            address[] memory poolTokenAddresses = new address[](1);
            poolTokenAddresses[0] = address(poolToken);
            morpho.claimRewards(poolTokenAddresses, false);

            comp.safeTransfer(_user, rewardsAmount);
        }
    }

    /// INTERNAL ///

    function _beforeWithdraw(
        address _user,
        uint256 _amount,
        uint256
    ) internal override {
        _accrueUserUnclaimedRewards(_user);

        morpho.withdraw(address(poolToken), _amount);
    }

    function _afterDeposit(
        address _user,
        uint256 _amount,
        uint256
    ) internal override {
        _accrueUserUnclaimedRewards(_user);

        asset.safeApprove(address(morpho), _amount);
        morpho.supply(address(poolToken), address(this), _amount);
    }

    /// @notice Accrues unclaimed rewards for the cToken addresses and returns the total unclaimed rewards.
    /// @param _user The address of the user.
    function _accrueUserUnclaimedRewards(address _user) internal {
        address _poolTokenAddress = address(poolToken);
        IComptroller.CompMarketState memory supplyState = comptroller.compSupplyState(
            _poolTokenAddress
        );

        uint256 deltaBlocks = block.number - supplyState.block;
        uint256 supplySpeed = comptroller.compSupplySpeeds(_poolTokenAddress);

        uint224 currentRewardsIndex;
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint256 supplyTokens = ICToken(_poolTokenAddress).totalSupply();
            uint256 compAccrued = deltaBlocks * supplySpeed;
            uint256 ratio = supplyTokens > 0 ? (compAccrued * 1e36) / supplyTokens : 0;

            currentRewardsIndex = uint224(supplyState.index + ratio);
        } else currentRewardsIndex = supplyState.index;

        uint256 userRewardsIndex = compRewardsIndex[_user];
        compRewardsIndex[_user] = currentRewardsIndex;

        if (userRewardsIndex != 0)
            userUnclaimedCompRewards[_user] +=
                (morpho.supplyBalanceInOf(_poolTokenAddress, _user).onPool *
                    (currentRewardsIndex - userRewardsIndex)) /
                1e36;
    }
}
