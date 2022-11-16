// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.5.0;

import {IRewardsManager} from "@contracts/aave-v3/interfaces/IRewardsManager.sol";
import {ISupplyVaultBase} from "./ISupplyVaultBase.sol";

interface ISupplyVault is ISupplyVaultBase {
    function RAY() external view returns (uint256);

    function rewardsManager() external view returns (IRewardsManager);

    function rewardsIndex(address _rewardToken) external view returns (uint128);

    function userRewards(address _rewardToken, address _user)
        external
        view
        returns (uint128, uint128);

    function getAllUnclaimedRewards(address _user)
        external
        view
        returns (address[] memory rewardTokens, uint256[] memory unclaimedAmounts);

    function getUnclaimedRewards(address _user, address _rewardToken)
        external
        view
        returns (uint256);

    function claimRewards(address _user)
        external
        returns (address[] memory rewardTokens, uint256[] memory claimedAmounts);
}
