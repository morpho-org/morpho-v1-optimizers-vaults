// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@aave/periphery-v3/contracts/rewards/libraries/RewardsDataTypes.sol";

import "./SupplyVaultUpgradeable.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable tokenized Vault implementation for Morpho-Compound, which can harvest accrued COMP rewards, swap them and re-supply them through Morpho-Compound.
contract SupplyVault is SupplyVaultUpgradeable {
    using SafeTransferLib for ERC20;
    using PercentageMath for uint256;
    using WadRayMath for uint256;

    /// STORAGE ///

    RewardsDataTypes.AssetData public localAssetData; // The local data related to the market.

    /// EVENTS ///

    /// @dev Emitted when rewards of an asset are accrued on behalf of a user.
    /// @param _reward The address of the reward token.
    /// @param _user The address of the user that rewards are accrued on behalf of.
    /// @param _assetIndex The index of the asset distribution.
    /// @param _userIndex The index of the asset distribution on behalf of the user.
    /// @param _rewardsAccrued The amount of rewards accrued.
    event Accrued(
        address indexed _reward,
        address indexed _user,
        uint256 _assetIndex,
        uint256 _userIndex,
        uint256 _rewardsAccrued
    );

    /// UPGRADE ///

    /// @dev Initializes the vault.
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

    /// @notice Returns user's rewards for the specificied reward token.
    /// @param _user The address of the user.
    /// @param _reward The address of the reward token
    /// @return The user's rewards in reward token.
    function getUserRewards(address _user, address _reward) external view returns (uint256) {
        return _getUserReward(_user, _reward);
    }

    /// @notice Returns the user's index for the specified asset and reward token.
    /// @param _user The address of the user.
    /// @param _asset The address of the reference asset of the distribution (aToken or variable debt token).
    /// @param _reward The address of the reward token.
    /// @return The user's index.
    function getUserAssetIndex(
        address _user,
        address _asset,
        address _reward
    ) external view returns (uint256) {
        return localAssetData.rewards[_reward].usersData[_user].index;
    }

    function claimRewards(address _user)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        rewardsList = rewardsController.getRewardsList();
        uint256 rewardsListLength = rewardsList.length;
        claimedAmounts = new uint256[](rewardsListLength);

        _updateData(_user);

        for (uint256 i; i < rewardsListLength; ) {
            uint256 rewardAmount = localAssetData.rewards[rewardsList[i]].usersData[_user].accrued;

            if (rewardAmount != 0) {
                claimedAmounts[i] = rewardAmount;
                localAssetData.rewards[rewardsList[i]].usersData[_user].accrued = 0;
            }

            ERC20(rewardsList[i]).safeTransfer(_user, rewardAmount);

            unchecked {
                ++i;
            }
        }
    }

    /// INTERNAL ///

    function _beforeInteraction(address _user) internal override {
        _updateData(_user);
    }

    /// @dev Updates the state of the distribution for the specified reward.
    /// @param _totalSupply The current total supply of underlying assets for this distribution.
    /// @param _assetUnit The asset's unit (10**decimals).
    /// @return newIndex The new distribution index.
    /// @return indexUpdated True if the index was updated, false otherwise.
    function _updateRewardData(
        RewardsDataTypes.RewardData storage _localRewardData,
        address _asset,
        address _reward,
        uint256 _totalSupply,
        uint256 _assetUnit
    ) internal returns (uint256 newIndex, bool indexUpdated) {
        uint256 oldIndex;
        (oldIndex, newIndex) = _getAssetIndex(
            _localRewardData,
            _asset,
            _reward,
            _totalSupply,
            _assetUnit
        );

        if (newIndex != oldIndex) {
            require(newIndex <= type(uint104).max, "INDEX_OVERFLOW");

            indexUpdated = true;

            // Optimization: storing one after another saves one SSTORE.
            _localRewardData.index = uint104(newIndex);
            _localRewardData.lastUpdateTimestamp = uint32(block.timestamp);
        } else _localRewardData.lastUpdateTimestamp = uint32(block.timestamp);

        return (newIndex, indexUpdated);
    }

    /// @dev Updates the state of the distribution for the specific user.
    /// @param _user The address of the user.
    /// @param _userBalance The current user asset balance.
    /// @param _newAssetIndex The new index of the asset distribution.
    /// @param _assetUnit The asset's unit (10**decimals).
    /// @return rewardsAccrued The rewards accrued since the last update.
    /// @return dataUpdated True if the data was updated, false otherwise.
    function _updateUserData(
        RewardsDataTypes.RewardData storage _localRewardData,
        address _user,
        uint256 _userBalance,
        uint256 _newAssetIndex,
        uint256 _assetUnit
    ) internal returns (uint256 rewardsAccrued, bool dataUpdated) {
        uint256 userIndex = _localRewardData.usersData[_user].index;

        if ((dataUpdated = userIndex != _newAssetIndex)) {
            // Already checked for overflow in _updateRewardData.
            _localRewardData.usersData[_user].index = uint104(_newAssetIndex);

            if (_userBalance != 0) {
                rewardsAccrued = _getRewards(_userBalance, _newAssetIndex, userIndex, _assetUnit);

                _localRewardData.usersData[_user].accrued += uint128(rewardsAccrued);
            }
        }
    }

    /// @dev Iterates and accrues all the rewards for asset of the specific user.
    /// @param _user The user address.
    function _updateData(address _user) internal {
        address $asset = asset;
        address[] memory availableRewards = rewardsController.getRewardsByAsset($asset);
        uint256 numAvailableRewards = availableRewards.length;
        if (numAvailableRewards == 0) return;

        unchecked {
            uint256 assetUnit = 10**rewardsController.getAssetDecimals($asset);

            for (uint128 i; i < numAvailableRewards; ++i) {
                address reward = availableRewards[i];
                RewardsDataTypes.RewardData storage localRewardData = localAssetData.rewards[
                    reward
                ];

                (uint256 newAssetIndex, bool rewardDataUpdated) = _updateRewardData(
                    localRewardData,
                    $asset,
                    reward,
                    IScaledBalanceToken(address(poolToken)).scaledTotalSupply(),
                    assetUnit
                );

                (uint256 rewardsAccrued, bool userDataUpdated) = _updateUserData(
                    localRewardData,
                    _user,
                    balanceOf(_user),
                    newAssetIndex,
                    assetUnit
                );

                if (rewardDataUpdated || userDataUpdated)
                    emit Accrued(reward, _user, newAssetIndex, newAssetIndex, rewardsAccrued);
            }
        }
    }

    /// @dev Returns the accrued unclaimed amount of a reward from a user over a list of distribution.
    /// @param _user The address of the user.
    /// @param _reward The address of the reward token.
    /// @return unclaimedRewards The accrued rewards for the user until the moment.
    function _getUserReward(address _user, address _reward)
        internal
        view
        returns (uint256 unclaimedRewards)
    {
        unclaimedRewards +=
            _getPendingRewards(_user, _reward) +
            localAssetData.rewards[_reward].usersData[_user].accrued;
    }

    /// @dev Computes the pending (not yet accrued) rewards since the last user action.
    /// @param _user The address of the user.
    /// @param _reward The address of the reward token.
    /// @return The pending rewards for the user since the last user action.
    function _getPendingRewards(address _user, address _reward) internal view returns (uint256) {
        RewardsDataTypes.RewardData storage localRewardData = localAssetData.rewards[_reward];

        uint256 assetUnit;
        // TODO: store this at initilisation.
        unchecked {
            assetUnit = 10**rewardsController.getAssetDecimals(asset);
        }

        (, uint256 nextIndex) = _getAssetIndex(
            localRewardData,
            asset,
            _reward,
            IScaledBalanceToken(address(poolToken)).scaledTotalSupply(),
            assetUnit
        );

        return
            _getRewards(
                balanceOf(_user),
                nextIndex,
                localRewardData.usersData[_user].index,
                assetUnit
            );
    }

    /// @dev Computes user's accrued rewards on a distribution.
    /// @param _userBalance The current user asset balance.
    /// @param _reserveIndex The current index of the distribution.
    /// @param _userIndex The index stored for the user, representing its staking moment.
    /// @param _assetUnit The asset's unit (10**decimals).
    /// @return rewards The rewards accrued.
    function _getRewards(
        uint256 _userBalance,
        uint256 _reserveIndex,
        uint256 _userIndex,
        uint256 _assetUnit
    ) internal view returns (uint256 rewards) {
        rewards = _userBalance * (_reserveIndex - _userIndex);
        assembly {
            rewards := div(rewards, _assetUnit)
        }
    }

    /// @dev Computes the next value of an specific distribution index, with validations.
    /// @param _totalSupply of the asset being rewarded.
    /// @param _assetUnit The asset's unit (10**decimals).
    /// @return The former index and the new index in this order.
    function _getAssetIndex(
        RewardsDataTypes.RewardData storage _localRewardData,
        address _asset,
        address _reward,
        uint256 _totalSupply,
        uint256 _assetUnit
    ) internal view returns (uint256, uint256) {
        uint256 currentTimestamp = block.timestamp;

        if (currentTimestamp == _localRewardData.lastUpdateTimestamp)
            return (_localRewardData.index, _localRewardData.index);
        else {
            (
                uint256 rewardIndex,
                uint256 emissionPerSecond,
                uint256 lastUpdateTimestamp,
                uint256 distributionEnd
            ) = rewardsController.getRewardsData(_asset, _reward);

            if (
                emissionPerSecond == 0 ||
                _totalSupply == 0 ||
                lastUpdateTimestamp == currentTimestamp ||
                lastUpdateTimestamp >= distributionEnd
            ) return (_localRewardData.index, rewardIndex);

            currentTimestamp = currentTimestamp > distributionEnd
                ? distributionEnd
                : currentTimestamp;
            uint256 firstTerm = emissionPerSecond *
                (currentTimestamp - lastUpdateTimestamp) *
                _assetUnit;
            assembly {
                firstTerm := div(firstTerm, _totalSupply)
            }
            return (_localRewardData.index, (firstTerm + rewardIndex));
        }
    }
}
