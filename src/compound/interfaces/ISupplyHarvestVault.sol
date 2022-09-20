// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.8.0;

import {IERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {ISwapper} from "../../interfaces/ISwapper.sol";

interface ISupplyHarvestVault is IERC4626Upgradeable {
    function MAX_BASIS_POINTS() external view returns (uint16);

    function MAX_UNISWAP_FEE() external view returns (uint24);

    function SWAP_ROUTER() external view returns (ISwapRouter);

    function isEth() external view returns (bool);

    function harvestConfig()
        external
        view
        returns (
            uint24,
            uint24,
            uint16
        );

    function compSwapFee() external view returns (uint24);

    function assetSwapFee() external view returns (uint24);

    function harvestingFee() external view returns (uint16);

    function setCompSwapFee(uint24 _newCompSwapFee) external;

    function setAssetSwapFee(uint24 _newAssetSwapFee) external;

    function setHarvestingFee(uint16 _newHarvestingFee) external;

    function harvest(address _receiver)
        external
        returns (uint256 rewardsAmount, uint256 rewardsFee);
}
