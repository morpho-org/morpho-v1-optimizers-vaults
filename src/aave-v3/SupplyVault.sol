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

    /// STRUCTS ///

    struct RewardData {
        uint128 index;
        uint128 accrued;
    }

    struct UserData {
        uint128 index;
        uint128 accrued;
    }

    /// STORAGE ///

    IRewardsManager public rewardsManager;
    mapping(address => uint256) public rewardIndex;
    mapping(address => mapping(address => UserData)) public userData;

    /// EVENTS ///

    /// @dev Emitted when rewards of an asset are accrued on behalf of a user.
    /// @param reward The address of the reward token.
    /// @param user The address of the user that rewards are accrued on behalf of.
    /// @param userIndex The index of the asset distribution on behalf of the user.
    /// @param rewardsAccrued The amount of rewards accrued.
    event Accrued(
        address indexed reward,
        address indexed user,
        uint256 userIndex,
        uint256 rewardsAccrued
    );

    event Claimed(address reward, address user, uint256 claimed);

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

        rewardsManager = IMoprho(_morphoAddress).rewardsManager();
    }

    /// EXTERNAL ///

    function claimRewards(address _user)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        rewardsList = rewardsController.getRewardsByAsset(address(poolToken));
        uint256 rewardsListLength = rewardsList.length;
        claimedAmounts = new uint256[](rewardsListLength);

        _beforeInteraction(_user);

        for (uint256 i; i < rewardsListLength; ) {
            uint256 rewardAmount = userData[rewardsList[i]][_user].accrued;

            if (rewardAmount != 0) {
                claimedAmounts[i] = rewardAmount;
                userData[rewardsList[i]][_user].accrued = 0;
            }

            ERC20(rewardsList[i]).safeTransfer(_user, rewardAmount);

            emit Claimed(reward, _user, rewardAmount);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns user's rewards for the specified assets and for all reward tokens.
    /// @param _assets The list of assets to retrieve rewards.
    /// @param _user The address of the user.
    /// @return rewardsList The list of reward tokens.
    /// @return unclaimedAmounts The list of unclaimed reward amounts.
    function getAllUserRewards(address[] calldata _assets, address _user)
        external
        view
        returns (address[] memory rewardsList, uint256[] memory unclaimedAmounts)
    {
        address[] memory poolTokenArray = [](1);
        poolTokenArray[0] = address(poolToken);

        address[] memory claimableAmounts;
        (rewardsList, claimableAmounts) = morpho.getAllUserRewards(poolTokenArray, address(this));
        uint256 rewardsListLength = rewardsList.length;

        for (uint256 i; i < rewardsListLength; ) {
            address reward = rewardsList[i];
            uint256 claimed = claimableAmounts[i];

            uint256 newIndex = rewardIndex[reward].index + (claimed * 1e18) / totalShares;

            unclaimedAmounts[i] =
                userData[reward][_user].accrued +
                shares[_user] *
                (userData[reward][_user].index - newIndex);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns user's rewards for the specificied reward token.
    /// @param _user The address of the user.
    /// @param _reward The address of the reward token
    /// @return The user's rewards in reward token.
    function getUserRewards(address _user, address _reward) external view returns (uint256) {
        address[] memory poolTokenArray = [](1);
        poolTokenArray[0] = address(poolToken);

        uint256 claimable = rewardsManager.getUserRewards(poolTokenArray, address(this), _reward);
        uint256 newIndex = rewardIndex[_reward].index + (claimable * 1e18) / totalShares;

        return
            userData[reward][_user].accrued +
            shares[_user] *
            (userData[_reward][_user].index - newIndex);
    }

    /// INTERNAL ///

    function _beforeInteraction(address _user) internal override {
        address[] memory poolTokenArray = [](1);
        poolTokenArray[0] = address(poolToken);

        (address[] memory rewardsList, uint256[] memory claimedAmounts) = morpho.claimRewards(
            poolTokenArray,
            false
        );
        uint256 rewardsListLength = rewardsList.length;

        for (uint256 i; i < rewardsListLength; ) {
            address reward = rewardsList[i];
            uint256 claimed = claimedAmounts[i];

            uint256 newIndex = rewardIndex[reward].index + (claimed * 1e18) / totalShares;
            rewardIndex[reward].index = newIndex;
            rewardIndex[reward].accrued += claimed;

            uint256 accrued = userData[reward][_user].accrued +
                shares[_user] *
                (userData[reward][_user].index - newIndex);

            userData[reward][_user].accrued = accrued;
            userData[reward][_user].index = newIndex;

            emit Accrued(rewards, _user, newIndex, accrued);

            unchecked {
                ++i;
            }
        }
    }
}
