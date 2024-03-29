// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import {ISupplyVault} from "./interfaces/ISupplyVault.sol";

import {ERC20, SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "@rari-capital/solmate/src/utils/SafeCastLib.sol";

import {SupplyVaultBase} from "./SupplyVaultBase.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Compound, which tracks rewards from Compound's pool accrued by its users.
contract SupplyVault is ISupplyVault, SupplyVaultBase {
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;
    using SafeTransferLib for ERC20;

    /// EVENTS ///

    /// @notice Emitted when a user accrues its rewards.
    /// @param user The address of the user.
    /// @param index The new index of the user (also the global at the moment of the update).
    /// @param unclaimed The new unclaimed amount of the user.
    event Accrued(address indexed user, uint256 index, uint256 unclaimed);

    /// @notice Emitted when a user claims its rewards.
    /// @param user The address of the user.
    /// @param claimed The amount of rewards claimed.
    event Claimed(address indexed user, uint256 claimed);

    /// STRUCTS ///

    struct UserRewardsData {
        uint128 index; // Rewards index at the user's last interaction with the vault.
        uint128 unclaimed; // User's unclaimed rewards in underlying reward token.
    }

    /// STORAGE ///

    uint256 public rewardsIndex; // The vault's rewards index.
    mapping(address => UserRewardsData) public userRewards; // The rewards data of a user, used to track accrued rewards.

    /// CONSTRUCTOR ///

    /// @dev Initializes immutable state variables.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _morphoToken The address of the Morpho Token.
    /// @param _lens The address of the Morpho Lens.
    /// @param _recipient The recipient of the rewards that will redistribute them to vault's users.
    constructor(
        address _morpho,
        address _morphoToken,
        address _lens,
        address _recipient
    ) SupplyVaultBase(_morpho, _morphoToken, _lens, _recipient) {}

    /// INITIALIZER ///

    /// @notice Initializes the vault.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function initialize(
        address _poolToken,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) external initializer {
        __SupplyVaultBase_init(_poolToken, _name, _symbol, _initialDeposit);
    }

    /// EXTERNAL ///

    /// @notice Claims rewards on behalf of `_user`.
    /// @param _user The address of the user to claim rewards for.
    /// @return rewardsAmount The amount of rewards claimed.
    function claimRewards(address _user) external returns (uint256 rewardsAmount) {
        rewardsAmount = _accrueUnclaimedRewards(_user);
        if (rewardsAmount == 0) return rewardsAmount;

        userRewards[_user].unclaimed = 0;

        comp.safeTransfer(_user, rewardsAmount);

        emit Claimed(_user, rewardsAmount);
    }

    /// INTERNAL ///

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint256 newRewardsIndex = _claimVaultRewards();
        _accrueUnclaimedRewardsFromRewardsIndex(from, newRewardsIndex);
        _accrueUnclaimedRewardsFromRewardsIndex(to, newRewardsIndex);

        super._beforeTokenTransfer(from, to, amount);
    }

    function _claimVaultRewards() internal returns (uint256 newRewardsIndex) {
        newRewardsIndex = rewardsIndex;

        uint256 supply = totalSupply();
        if (supply > 0) {
            address[] memory poolTokens = new address[](1);
            poolTokens[0] = poolToken;

            newRewardsIndex += morpho.claimRewards(poolTokens, false).divWadDown(supply);
            rewardsIndex = newRewardsIndex;
        }
    }

    function _accrueUnclaimedRewards(address _user) internal returns (uint256 unclaimed) {
        return _accrueUnclaimedRewardsFromRewardsIndex(_user, _claimVaultRewards());
    }

    function _accrueUnclaimedRewardsFromRewardsIndex(address _user, uint256 _newRewardsIndex)
        internal
        returns (uint256 unclaimed)
    {
        if (_user == address(0)) return unclaimed;

        UserRewardsData storage userRewardsData = userRewards[_user];
        uint256 rewardsIndexDiff;

        // Safe because we always have `rewardsIndex` >= `userRewardsData.index`.
        unchecked {
            rewardsIndexDiff = _newRewardsIndex - userRewardsData.index;
        }

        unclaimed = userRewardsData.unclaimed;
        if (rewardsIndexDiff > 0) {
            unclaimed += balanceOf(_user).mulWadDown(rewardsIndexDiff);
            userRewardsData.unclaimed = unclaimed.safeCastTo128();
            userRewardsData.index = _newRewardsIndex.safeCastTo128();

            emit Accrued(_user, _newRewardsIndex, unclaimed);
        }
    }
}
