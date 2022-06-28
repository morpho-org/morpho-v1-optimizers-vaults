// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@aave/periphery-v3/contracts/rewards/libraries/RewardsDataTypes.sol";

import "./SupplyVaultUpgradeable.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Compound, which can harvest accrued COMP rewards, swap them and re-supply them through Morpho-Compound.
contract SupplyVault is SupplyVaultUpgradeable {
    using SafeTransferLib for ERC20;
    using PercentageMath for uint256;
    using WadRayMath for uint256;

    /// STRUCTS ///

    struct UserData {
        uint128 index;
        uint128 accrued;
    }

    /// STORAGE ///

    uint256 public assetUnit;
    mapping(address => mapping(address => UserData)) public userData;

    /// EVENTS ///

    /// @dev Emitted when rewards of an asset are accrued on behalf of a user.
    /// @param _reward The address of the reward token.
    /// @param _user The address of the user that rewards are accrued on behalf of.
    /// @param _userIndex The index of the asset distribution on behalf of the user.
    /// @param _rewardsAccrued The amount of rewards accrued.
    event Accrued(
        address indexed _reward,
        address indexed _user,
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

        unchecked {
            assetUnit = 10**rewardsController.getAssetDecimals(asset);
        }
    }

    /// EXTERNAL ///

    /// @notice Returns user's rewards for the specificied reward token.
    /// @param _user The address of the user.
    /// @param _reward The address of the reward token
    /// @return The user's rewards in reward token.
    function getUserRewards(address _user, address _reward) external view returns (uint256) {
        return _getUserReward(_user, _reward);
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
            uint256 rewardAmount = userData[rewardsList[i]][_user].accrued;

            if (rewardAmount != 0) {
                claimedAmounts[i] = rewardAmount;
                userData[rewardsList[i]][_user].accrued = 0;
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

    /// @dev Updates the state of the distribution for the specific user.
    /// @param _user The address of the user.
    /// @param _userBalance The current user asset balance.
    /// @param _newAssetIndex The new index of the asset distribution.
    /// @param _assetUnit The asset's unit (10**decimals).
    /// @return rewardsAccrued The rewards accrued since the last update.
    /// @return dataUpdated True if the data was updated, false otherwise.
    function _updateUserData(
        address _user,
        address _reward,
        uint256 _userBalance,
        uint256 _newAssetIndex,
        uint256 _assetUnit
    ) internal returns (uint256 rewardsAccrued, bool dataUpdated) {
        uint256 userIndex = userData[_reward][_user].index;

        if ((dataUpdated = userIndex != _newAssetIndex)) {
            userData[_reward][_user].index = uint128(_newAssetIndex);

            if (_userBalance != 0) {
                rewardsAccrued = _getRewards(_userBalance, _newAssetIndex, userIndex, _assetUnit);

                userData[_reward][_user].accrued += uint128(rewardsAccrued);
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
            uint256 assetUnit_ = assetUnit;

            for (uint128 i; i < numAvailableRewards; ++i) {
                address reward = availableRewards[i];

                uint256 newAssetIndex = _getAssetIndex(
                    $asset,
                    reward,
                    IScaledBalanceToken(address(poolToken)).scaledTotalSupply(),
                    assetUnit_
                );

                (uint256 rewardsAccrued, bool userDataUpdated) = _updateUserData(
                    _user,
                    reward,
                    balanceOf(_user),
                    newAssetIndex,
                    assetUnit_
                );

                if (userDataUpdated) emit Accrued(reward, _user, newAssetIndex, rewardsAccrued);
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
        unclaimedRewards += _getPendingRewards(_user, _reward) + userData[_reward][_user].accrued;
    }

    /// @dev Computes the pending (not yet accrued) rewards since the last user action.
    /// @param _user The address of the user.
    /// @param _reward The address of the reward token.
    /// @return The pending rewards for the user since the last user action.
    function _getPendingRewards(address _user, address _reward) internal view returns (uint256) {
        UserData storage rewardsData = userData.rewards[_reward];
        uint256 assetUnit_ = assetUnit;

        (, uint256 nextIndex) = _getAssetIndex(
            asset,
            _reward,
            IScaledBalanceToken(address(poolToken)).scaledTotalSupply(),
            assetUnit_
        );

        return _getRewards(balanceOf(_user), nextIndex, userData[_user].index, assetUnit_);
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
    /// @return The new index.
    function _getAssetIndex(
        address _asset,
        address _reward,
        uint256 _totalSupply,
        uint256 _assetUnit
    ) internal view returns (uint256) {
        uint256 currentTimestamp = block.timestamp;

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
        ) return rewardIndex;

        currentTimestamp = currentTimestamp > distributionEnd ? distributionEnd : currentTimestamp;
        uint256 firstTerm = emissionPerSecond *
            (currentTimestamp - lastUpdateTimestamp) *
            _assetUnit;
        assembly {
            firstTerm := div(firstTerm, _totalSupply)
        }
        return firstTerm + rewardIndex;
    }
}
