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

    struct UserRewards {
        uint128 index; // User index for the reward token.
        uint128 unclaimed; // User's unclaimed rewards.
    }

    uint256 public rewardsIndex; // The vault's rewards index.
    mapping(address => UserRewards) public userRewards; // The rewards index of a user, used to track rewards accrued.

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

    /// @notice Claims rewards on behalf of `_user`.
    /// @param _user The address of the user to claim rewards for.
    /// @return rewardsAmount The amount of rewards claimed.
    function claimRewards(address _user) external returns (uint256 rewardsAmount) {
        _accrueUserUnclaimedRewards(_user);

        rewardsAmount = userRewards[_user].unclaimed;
        if (rewardsAmount > 0) {
            userRewards[_user].unclaimed = 0;

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

        uint256 rewardsIndexDiff = rewardsIndex - userRewards[_user].index;
        if (rewardsIndexDiff > 0) {
            userRewards[_user].unclaimed += uint128(balanceOf(_user).mul(rewardsIndexDiff));
            userRewards[_user].index = uint128(rewardsIndex);
        }
    }
}
