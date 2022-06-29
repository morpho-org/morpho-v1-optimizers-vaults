// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";

import "./SupplyVaultUpgradeable.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Aave V3, which tracks rewards from Aave's pool accrued by its users.
contract SupplyVault is SupplyVaultUpgradeable {
    using SafeTransferLib for ERC20;
    using WadRayMath for uint256;

    /// STRUCTS ///

    struct UserRewards {
        uint128 index; // User rewards index for a given reward token (in wad).
        uint128 unclaimed; // Unclaimed amount for a given reward token (in reward tokens).
    }

    /// STORAGE ///

    IRewardsManager public rewardsManager; // Morpho's rewards manager.

    mapping(address => uint128) public rewardsIndex; // The current reward index for the given reward token.
    mapping(address => mapping(address => UserRewards)) public userRewards; // User rewards data. rewardToken -> user -> userRewards.

    /// EVENTS ///

    /// @notice Emitted when rewards of an asset are accrued on behalf of a user.
    /// @param rewardToken The address of the reward token.
    /// @param user The address of the user that rewards are accrued on behalf of.
    /// @param rewardsIndex The index of the asset distribution on behalf of the user.
    /// @param accruedRewards The amount of rewards accrued.
    event RewardsAccrued(
        address indexed rewardToken,
        address indexed user,
        uint128 rewardsIndex,
        uint128 accruedRewards
    );

    /// @notice Emitted when rewards of an asset are claimed on behalf of a user.
    /// @param rewardToken The address of the reward token.
    /// @param user The address of the user that rewards are claimed on behalf of.
    /// @param claimedRewards The amount of rewards claimed.
    event RewardsClaimed(address indexed rewardToken, address indexed user, uint256 claimedRewards);

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

        rewardsManager = IMorpho(_morphoAddress).rewardsManager();
    }

    /// EXTERNAL ///

    /// @notice Claims rewards on behalf of `_user`.
    /// @param _user The address of the user to claim rewards for.
    /// @return rewardTokens The list of reward tokens.
    /// @return claimedAmounts The list of claimed amounts for each reward tokens.
    function claimRewards(address _user)
        external
        returns (address[] memory rewardTokens, uint256[] memory claimedAmounts)
    {
        _accrueUnclaimedRewards(_user);

        rewardTokens = rewardsController.getRewardsByAsset(address(poolToken));

        uint256 nbRewardTokens = rewardTokens.length;
        claimedAmounts = new uint256[](nbRewardTokens);

        for (uint256 i; i < nbRewardTokens; ) {
            address rewardToken = rewardTokens[i];
            uint128 unclaimedAmount = userRewards[rewardToken][_user].unclaimed;

            if (unclaimedAmount > 0) {
                claimedAmounts[i] = unclaimedAmount;
                userRewards[rewardToken][_user].unclaimed = 0;

                ERC20(rewardToken).safeTransfer(_user, unclaimedAmount);

                emit RewardsClaimed(rewardToken, _user, unclaimedAmount);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns a given user's unclaimed rewards for all reward tokens.
    /// @param _user The address of the user.
    /// @return rewardTokens The list of reward tokens.
    /// @return unclaimedAmounts The list of unclaimed amounts for each reward token.
    function getAllUnclaimedRewards(address _user)
        external
        view
        returns (address[] memory rewardTokens, uint256[] memory unclaimedAmounts)
    {
        uint256 supply = totalSupply();
        if (supply > 0) {
            address[] memory poolTokens = new address[](1);
            poolTokens[0] = address(poolToken);

            uint256[] memory claimableAmounts;
            (rewardTokens, claimableAmounts) = rewardsManager.getAllUserRewards(
                poolTokens,
                address(this)
            );

            uint256 nbRewardTokens = rewardTokens.length;
            for (uint256 i; i < nbRewardTokens; ) {
                address rewardToken = rewardTokens[i];

                unclaimedAmounts[i] =
                    userRewards[rewardToken][_user].unclaimed +
                    balanceOf(_user).wadMul(
                        rewardsIndex[rewardToken] +
                            claimableAmounts[i].wadDiv(totalSupply()) -
                            userRewards[rewardToken][_user].index
                    );

                unchecked {
                    ++i;
                }
            }
        }
    }

    /// @notice Returns user's rewards for the specificied reward token.
    /// @param _user The address of the user.
    /// @param _rewardToken The address of the reward token
    /// @return The user's rewards in reward token.
    function getUnclaimedRewards(address _user, address _rewardToken)
        external
        view
        returns (uint256)
    {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;

        address[] memory poolTokens = new address[](1);
        poolTokens[0] = address(poolToken);

        uint256 claimableRewards = rewardsManager.getUserRewards(
            poolTokens,
            address(this),
            _rewardToken
        );
        UserRewards memory _userRewards = userRewards[_rewardToken][_user];

        return
            _userRewards.unclaimed +
            balanceOf(_user).wadMul(
                rewardsIndex[_rewardToken] +
                    claimableRewards.wadDiv(totalSupply()) -
                    _userRewards.index
            );
    }

    /// INTERNAL ///

    function _beforeInteraction(address _user) internal override {
        _accrueUnclaimedRewards(_user);
    }

    function _accrueUnclaimedRewards(address _user) internal {
        uint256 supply = totalSupply();
        if (supply == 0) return;

        address[] memory poolTokens = new address[](1);
        poolTokens[0] = address(poolToken);

        (address[] memory rewardTokens, uint256[] memory claimedAmounts) = morpho.claimRewards(
            poolTokens,
            false
        );

        uint256 nbRewardTokens = rewardTokens.length;
        for (uint256 i; i < nbRewardTokens; ) {
            address rewardToken = rewardTokens[i];
            uint256 claimedAmount = claimedAmounts[i];

            uint128 newRewardsIndex = rewardsIndex[rewardToken];
            if (claimedAmount > 0) {
                newRewardsIndex += uint128(claimedAmount.wadDiv(supply));
                rewardsIndex[rewardToken] = newRewardsIndex;
            }

            uint256 rewardsIndexDiff = newRewardsIndex - userRewards[rewardToken][_user].index;
            if (rewardsIndexDiff > 0) {
                uint128 accruedRewards = uint128(balanceOf(_user).wadMul(rewardsIndexDiff));
                userRewards[rewardToken][_user].unclaimed += accruedRewards;
                userRewards[rewardToken][_user].index = newRewardsIndex;

                emit RewardsAccrued(rewardToken, _user, newRewardsIndex, accruedRewards);
            }

            unchecked {
                ++i;
            }
        }
    }
}
