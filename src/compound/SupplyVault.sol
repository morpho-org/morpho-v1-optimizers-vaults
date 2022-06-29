// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./SupplyVaultUpgradeable.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Compound, which can harvest accrued COMP rewards, swap them and re-supply them through Morpho-Compound.
contract SupplyVault is SupplyVaultUpgradeable {
    using SafeTransferLib for ERC20;
    using CompoundMath for uint256;

    /// STORAGE ///

    uint256 public rewardsIndex; // The vault's rewards index.
    mapping(address => uint256) public userRewardsIndex; // The rewards index of a user, used to track rewards accrued.
    mapping(address => uint256) public userUnclaimedRewards; // The total unclaimed rewards of a user.

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

    /// PUBLIC ///

    /// @notice Claims rewards from the underlying pool, swaps them for the underlying asset and supply them through Morpho.
    /// @return rewardsAmount The amount of rewards claimed, swapped then supplied through Morpho (in underlying).
    function claimRewards(address _user) public returns (uint256 rewardsAmount) {
        _accrueUserUnclaimedRewards(_user);

        rewardsAmount = userUnclaimedRewards[_user];
        if (rewardsAmount > 0) {
            userUnclaimedRewards[_user] = 0;

            comp.safeTransfer(_user, rewardsAmount);
        }
    }

    /// INTERNAL ///

    function _beforeInteraction(address _user) internal override {
        _accrueUserUnclaimedRewards(_user);
    }

    function _accrueUserUnclaimedRewards(address _user) internal {
        uint256 supply = totalSupply();
        if (supply > 0) {
            address[] memory poolTokenAddresses = new address[](1);
            poolTokenAddresses[0] = address(poolToken);
            rewardsIndex += morpho.claimRewards(poolTokenAddresses, false).div(supply);
        }

        uint256 rewardsIndexDiff = rewardsIndex - userRewardsIndex[_user];
        if (rewardsIndexDiff > 0) {
            userUnclaimedRewards[_user] += balanceOf(_user).mul(rewardsIndexDiff);
            userRewardsIndex[_user] = rewardsIndex;
        }
    }
}
