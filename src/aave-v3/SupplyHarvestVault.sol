// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../interfaces/ISwapper.sol";

import "@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol";

import "./SupplyVaultUpgradeable.sol";

/// @title SupplyHarvestVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Aave, which can harvest accrued COMP rewards, swap them and re-supply them through Morpho-Rewardsound.
contract SupplyHarvestVault is SupplyVaultUpgradeable {
    using SafeTransferLib for ERC20;
    using PercentageMath for uint256;
    using WadRayMath for uint256;

    /// EVENTS ///

    /// @notice Emitted when the fee for harvesting is set.
    /// @param newHarvestingFee The new harvesting fee.
    event HarvestingFeeSet(uint16 newHarvestingFee);

    /// @notice Emitted when the swapper is set.
    /// @param newSwapper The new swapper contract.
    event SwapperSet(address newSwapper);

    /// ERRORS ///

    /// @notice Thrown when the input is above the maximum basis points value (100%).
    error ExceedsMaxBasisPoints();

    /// STORAGE ///

    uint16 public constant MAX_BASIS_POINTS = 10_000; // 100% in basis points.

    uint16 public harvestingFee; // The fee taken by the claimer when harvesting the vault (in bps).
    ISwapper public swapper; // Swapper contract to swap reward tokens for underlying asset.

    /// UPGRADE ///

    /// @notice Initializes the vault.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    /// @param _harvestingFee The fee taken by the claimer when harvesting the vault (in bps).
    function initialize(
        address _morpho,
        address _poolToken,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit,
        uint16 _harvestingFee,
        address _swapper
    ) external initializer {
        __SupplyVaultUpgradeable_init(_morpho, _poolToken, _name, _symbol, _initialDeposit);

        harvestingFee = _harvestingFee;
        swapper = ISwapper(_swapper);
    }

    /// GOVERNANCE ///

    /// @notice Sets the fee taken by the claimer from the total amount of COMP rewards when harvesting the vault.
    /// @param _newHarvestingFee The new harvesting fee (in bps).
    function setHarvestingFee(uint16 _newHarvestingFee) external onlyOwner {
        if (_newHarvestingFee > MAX_BASIS_POINTS) revert ExceedsMaxBasisPoints();

        harvestingFee = _newHarvestingFee;
        emit HarvestingFeeSet(_newHarvestingFee);
    }

    /// @notice Sets the swapper contract to swap reward tokens for underlying asset.
    /// @param _swapper The new swapper to set.
    function setSwapper(address _swapper) external onlyOwner {
        swapper = ISwapper(_swapper);
        emit SwapperSet(_swapper);
    }

    /// EXTERNAL ///

    /// @notice Harvests the vault: claims rewards from the underlying pool, swaps them for the underlying asset and supply them through Morpho.
    /// @return rewardTokens The addresses of reward tokens claimed.
    /// @return rewardsAmounts The amount of rewards claimed for each reward token (in underlying).
    /// @return rewardsFees The amount of fees taken by the claimer for each reward token (in underlying).
    function harvest()
        external
        returns (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256[] memory rewardsFees
        )
    {
        address poolTokenMem = poolToken;
        address assetMem = asset();

        {
            address[] memory poolTokens = new address[](1);
            poolTokens[0] = poolTokenMem;
            (rewardTokens, rewardsAmounts) = morpho.claimRewards(poolTokens, false);
        }

        uint256 nbRewardTokens = rewardTokens.length;
        rewardsFees = new uint256[](nbRewardTokens);
        uint256 toSupply;

        for (uint256 i; i < nbRewardTokens; ) {
            uint256 rewardsAmount = rewardsAmounts[i];

            if (rewardsAmount > 0) {
                ERC20 rewardToken = ERC20(rewardTokens[i]);

                // Note: Uniswap pools are considered to have enough liquidity depth.
                // The amount swapped is considered low enough to avoid relying on a TWAP oracle.
                if (assetMem != address(rewardToken)) {
                    rewardToken.safeTransfer(address(swapper), rewardsAmount);
                    rewardsAmount = swapper.executeSwap(
                        address(rewardToken),
                        rewardsAmount,
                        assetMem,
                        address(this)
                    );

                    uint16 harvestingFeeMem = harvestingFee;
                    if (harvestingFeeMem > 0) {
                        rewardsFees[i] = rewardsAmount.percentMul(harvestingFeeMem);
                        rewardsAmount -= rewardsFees[i];
                        ERC20(assetMem).safeTransfer(msg.sender, rewardsFees[i]);
                    }
                }

                rewardsAmounts[i] = rewardsAmount;
                toSupply += rewardsAmount;
            }

            unchecked {
                ++i;
            }
        }

        morpho.supply(poolTokenMem, address(this), toSupply);
    }
}
