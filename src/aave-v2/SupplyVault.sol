// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import {IAaveIncentivesController} from "@contracts/aave-v2/interfaces/aave/IAaveIncentivesController.sol";
import {IMorpho} from "@contracts/aave-v2/interfaces/IMorpho.sol";

import {SafeTransferLib, ERC20} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "@rari-capital/solmate/src/utils/SafeCastLib.sol";

import {SupplyVaultBase} from "./SupplyVaultBase.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Aave V3, which tracks rewards from Aave's pool accrued by its users.
contract SupplyVault is SupplyVaultBase {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;

    /// STRUCTS ///

    struct UserRewardsData {
        uint128 index; // User rewards index for a given reward token (in wad).
        uint128 unclaimed; // Unclaimed amount for a given reward token (in reward tokens).
    }

    /// STORAGE ///

    uint256 public constant SCALE = 1e36;

    uint128 public rewardsIndex; // The current reward index for the given reward token.
    mapping(address => UserRewardsData) public userRewards; // User rewards data. rewardToken -> user -> userRewards.

    /// EVENTS ///

    /// @notice Emitted when rewards of an asset are accrued on behalf of a user.
    /// @param user The address of the user that rewards are accrued on behalf of.
    /// @param rewardsIndex The index of the asset distribution on behalf of the user.
    /// @param accruedRewards The amount of rewards accrued.
    event Accrued(address indexed user, uint128 rewardsIndex, uint128 accruedRewards);

    /// @notice Emitted when rewards of an asset are claimed on behalf of a user.
    /// @param user The address of the user that rewards are claimed on behalf of.
    /// @param claimedRewards The amount of rewards claimed.
    event Claimed(address indexed user, uint256 claimedRewards);

    /// UPGRADE ///

    /// @dev Initializes the vault.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function initialize(
        address _morpho,
        address _poolToken,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) external initializer {
        __SupplyVaultBase_init(_morpho, _poolToken, _name, _symbol, _initialDeposit);
    }

    /// EXTERNAL ///

    /// @notice Claims rewards on behalf of `_user`.
    /// @param _user The address of the user to claim rewards for.
    /// @return rewardsAmount The list of claimed amounts for each reward tokens.
    function claimRewards(address _user) external returns (uint256 rewardsAmount) {
        _accrueUnclaimedRewards(_user);

        UserRewardsData storage userRewardsData = userRewards[_user];

        uint128 unclaimedAmount = userRewardsData.unclaimed;
        if (unclaimedAmount > 0) {
            rewardsAmount = unclaimedAmount;
            userRewardsData.unclaimed = 0;

            aave.safeTransfer(_user, unclaimedAmount);

            emit Claimed(_user, unclaimedAmount);
        }
    }

    /// @notice Returns a given user's unclaimed rewards for all reward tokens.
    /// @param _user The address of the user.
    /// @return unclaimedAmount The list of unclaimed amounts for each reward token.
    function getAllUnclaimedRewards(address _user) external view returns (uint256 unclaimedAmount) {
        uint256 supply = totalSupply();
        if (supply > 0) {
            uint256 claimableAmount = incentivesController.getUserUnclaimedRewards(address(this));

            UserRewardsData memory userRewardsData = userRewards[_user];

            unclaimedAmount =
                userRewardsData.unclaimed +
                balanceOf(_user).mulDivDown(
                    (rewardsIndex + claimableAmount.mulDivDown(SCALE, totalSupply())) -
                        userRewardsData.index,
                    SCALE
                );
        }
    }

    /// @notice Returns user's rewards for the specificied reward token.
    /// @param _user The address of the user.
    /// @return The user's rewards in reward token.
    function getUnclaimedRewards(address _user) external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;

        address[] memory poolTokens = new address[](1);
        poolTokens[0] = poolToken;

        uint256 claimableRewards = incentivesController.getUserUnclaimedRewards(address(this));
        UserRewardsData memory rewards = userRewards[_user];

        return
            rewards.unclaimed +
            balanceOf(_user).mulDivDown(
                (rewardsIndex + claimableRewards.mulDivDown(SCALE, totalSupply()) - rewards.index),
                SCALE
            );
    }

    /// INTERNAL ///

    function _deposit(
        address _caller,
        address _receiver,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
        _accrueUnclaimedRewards(_receiver);
        super._deposit(_caller, _receiver, _assets, _shares);
    }

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
        _accrueUnclaimedRewards(_receiver);
        super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    function _accrueUnclaimedRewards(address _user) internal {
        uint256 claimedAmount;

        {
            address[] memory poolTokens = new address[](1);
            poolTokens[0] = poolToken;

            claimedAmount = morpho.claimRewards(poolTokens, false);
        }

        uint256 supply = totalSupply();
        uint128 rewardsIndexMem;

        if (supply > 0 && claimedAmount > 0) {
            rewardsIndexMem =
                rewardsIndex +
                claimedAmount.mulDivDown(SCALE, supply).safeCastTo128();
            rewardsIndex = rewardsIndexMem;
        } else rewardsIndexMem = rewardsIndex;

        UserRewardsData storage userRewardsData = userRewards[_user];
        uint256 rewardsIndexDiff;

        // Safe because we always have `rewardsIndex` >= `userRewardsData.index`.
        unchecked {
            rewardsIndexDiff = rewardsIndexMem - userRewardsData.index;
        }

        if (rewardsIndexDiff > 0) {
            uint128 accruedRewards = balanceOf(_user)
            .mulDivDown(rewardsIndexDiff, SCALE)
            .safeCastTo128();
            userRewardsData.unclaimed += accruedRewards;
            userRewardsData.index = rewardsIndexMem;

            emit Accrued(_user, rewardsIndexMem, accruedRewards);
        }
    }
}
