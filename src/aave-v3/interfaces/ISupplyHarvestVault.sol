// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.8.0;

import {ISupplyVaultBase} from "./ISupplyVaultBase.sol";
import {ISwapper} from "../../interfaces/ISwapper.sol";

interface ISupplyHarvestVault is ISupplyVaultBase {
    function MAX_BASIS_POINTS() external view returns (uint16);

    function harvestingFee() external view returns (uint16);

    function swapper() external view returns (ISwapper);

    function setHarvestingFee(uint16 _newHarvestingFee) external;

    function setSwapper(address _swapper) external;

    function harvest(address _receiver)
        external
        returns (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256 totalSupplied,
            uint256 totalRewardsFee
        );
}
