// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@aave/core-v3/contracts/interfaces/IPriceOracleGetter.sol";

import "./SupplyVaultUpgradeable.sol";

/// @title SupplyHarvestVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable tokenized Vault implementation for Morpho-Rewardsound, which can harvest accrued COMP rewards, swap them and re-supply them through Morpho-Rewardsound.
contract SupplyHarvestVault is SupplyVaultUpgradeable {
    using SafeTransferLib for ERC20;
    using PercentageMath for uint256;
    using WadRayMath for uint256;

    /// EVENTS ///

    /// @notice Emitted when the fee for harvesting is set.
    /// @param newHarvestingFee The new harvesting fee.
    event HarvestingFeeSet(uint16 newHarvestingFee);

    /// @notice Emitted when the fee for swapping rewards for WETH is set.
    /// @param newRewardsSwapFee The new rewards swap fee (in UniswapV3 fee unit).
    event RewardsSwapFeeSet(uint16 newRewardsSwapFee);

    /// @notice Emitted when the fee for swapping WETH for the underlying asset is set.
    /// @param newAssetSwapFee The new asset swap fee (in UniswapV3 fee unit).
    event AssetSwapFeeSet(uint16 newAssetSwapFee);

    /// @notice Emitted when the maximum slippage for harvesting is set.
    /// @param newMaxHarvestingSlippage The new maximum slippage allowed when swapping rewards for the underlying token (in bps).
    event MaxHarvestingSlippageSet(uint16 newMaxHarvestingSlippage);

    /// ERRORS ///

    /// @notice Thrown when the input is above the maximum basis points value (100%).
    error ExceedsMaxBasisPoints();

    /// @notice Thrown when the input is above the maximum UniswapV3 pool fee value (100%).
    error ExceedsMaxUniswapV3Fee();

    /// STORAGE ///

    uint16 public constant MAX_BASIS_POINTS = 10_000; // 100% in basis points.
    uint24 public constant MAX_UNISWAP_FEE = 1_000_000; // 100% in UniswapV3 fee units.
    ISwapRouter public constant SWAP_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    uint24 public rewardsSwapFee; // The fee taken by the UniswapV3Pool for swapping COMP rewards for WETH (in UniswapV3 fee unit).
    uint24 public assetSwapFee; // The fee taken by the UniswapV3Pool for swapping WETH for the underlying asset (in UniswapV3 fee unit).
    uint16 public harvestingFee; // The fee taken by the claimer when harvesting the vault (in bps).
    uint16 public maxHarvestingSlippage; // The maximum slippage allowed when swapping rewards for the underlying asset (in bps).

    /// UPGRADE ///

    /// @notice Initializes the vault.
    /// @param _morphoAddress The address of the main Morpho contract.
    /// @param _poolTokenAddress The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    /// @param _rewardsSwapFee The fee taken by the UniswapV3Pool for swapping COMP rewards for WETH (in UniswapV3 fee unit).
    /// @param _assetSwapFee The fee taken by the UniswapV3Pool for swapping WETH for the underlying asset (in UniswapV3 fee unit).
    /// @param _harvestingFee The fee taken by the claimer when harvesting the vault (in bps).
    /// @param _maxHarvestingSlippage The maximum slippage allowed when swapping rewards for the underlying asset (in bps).
    function initialize(
        address _morphoAddress,
        address _poolTokenAddress,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit,
        uint24 _rewardsSwapFee,
        uint24 _assetSwapFee,
        uint16 _harvestingFee,
        uint16 _maxHarvestingSlippage
    ) external initializer {
        __SupplyVault_init(_morphoAddress, _poolTokenAddress, _name, _symbol, _initialDeposit);

        rewardsSwapFee = _rewardsSwapFee;
        assetSwapFee = _assetSwapFee;
        harvestingFee = _harvestingFee;
        maxHarvestingSlippage = _maxHarvestingSlippage;
    }

    /// GOVERNANCE ///

    /// @notice Sets the fee taken by the UniswapV3Pool for swapping COMP rewards for WETH.
    /// @param _newRewardsSwapFee The new rewards swap fee (in UniswapV3 fee unit).
    function setRewardsSwapFee(uint16 _newRewardsSwapFee) external onlyOwner {
        if (_newRewardsSwapFee > MAX_UNISWAP_FEE) revert ExceedsMaxUniswapV3Fee();

        rewardsSwapFee = _newRewardsSwapFee;
        emit RewardsSwapFeeSet(_newRewardsSwapFee);
    }

    /// @notice Sets the fee taken by the UniswapV3Pool for swapping WETH for the underlying asset.
    /// @param _newAssetSwapFee The new asset swap fee (in UniswapV3 fee unit).
    function setAssetSwapFee(uint16 _newAssetSwapFee) external onlyOwner {
        if (_newAssetSwapFee > MAX_UNISWAP_FEE) revert ExceedsMaxUniswapV3Fee();

        assetSwapFee = _newAssetSwapFee;
        emit AssetSwapFeeSet(_newAssetSwapFee);
    }

    /// @notice Sets the fee taken by the claimer from the total amount of COMP rewards when harvesting the vault.
    /// @param _newHarvestingFee The new harvesting fee (in bps).
    function setHarvestingFee(uint16 _newHarvestingFee) external onlyOwner {
        if (_newHarvestingFee > MAX_BASIS_POINTS) revert ExceedsMaxBasisPoints();

        harvestingFee = _newHarvestingFee;
        emit HarvestingFeeSet(_newHarvestingFee);
    }

    /// @notice Sets the maximum slippage allowed when swapping rewards for the underlying token.
    /// @param _newMaxHarvestingSlippage The new maximum slippage allowed when swapping rewards for the underlying token (in bps).
    function setMaxHarvestingSlippage(uint16 _newMaxHarvestingSlippage) external onlyOwner {
        if (_newMaxHarvestingSlippage > MAX_BASIS_POINTS) revert ExceedsMaxBasisPoints();

        maxHarvestingSlippage = _newMaxHarvestingSlippage;
        emit MaxHarvestingSlippageSet(_newMaxHarvestingSlippage);
    }

    /// EXTERNAL ///

    /// @notice Harvests the vault: claims rewards from the underlying pool, swaps them for the underlying asset and supply them through Morpho.
    /// @param _maxSlippage The maximum slippage allowed for the swap (in bps).
    /// @return rewardsAmount_ The amount of rewards claimed, swapped then supplied through Morpho (in underlying).
    /// @return rewardsFees The amount of fees taken by the claimer (in underlying).
    function harvest(uint16 _maxSlippage)
        external
        returns (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256[] memory rewardsFees
        )
    {
        address underlyingAddress = address(asset);
        address poolTokenAddress = address(poolToken);

        {
            address[] memory poolTokenAddresses = new address[](1);
            poolTokenAddresses[0] = poolTokenAddress;
            (rewardTokens, rewardsAmounts) = morpho.claimRewards(poolTokenAddresses, false);
        }

        IPriceOracleGetter oracle = IPriceOracleGetter(morpho.addressesProvider().getPriceOracle());

        for (uint256 i; i < rewardTokens.length; ) {
            ERC20 rewardToken = ERC20(rewardTokens[i]);
            uint256 rewardsAmount = rewardsAmounts[i];

            uint256 amountOutMinimum = rewardsAmount
            .mul(oracle.getAssetPrice(address(rewardToken)))
            .div(oracle.getAssetPrice(underlyingAddress))
            .mul(MAX_BASIS_POINTS - RewardsoundMath.min(_maxSlippage, maxHarvestingSlippage))
            .div(MAX_BASIS_POINTS);

            rewardToken.safeApprove(address(SWAP_ROUTER), rewardsAmount);
            rewardsAmount = SWAP_ROUTER.exactInput(
                ISwapRouter.ExactInputParams({
                    path: isEth
                        ? abi.encodePacked(address(rewards), rewardsSwapFee, wEth)
                        : abi.encodePacked(
                            address(rewards),
                            rewardsSwapFee,
                            wEth,
                            assetSwapFee,
                            underlyingAddress
                        ),
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: rewardsAmount,
                    amountOutMinimum: amountOutMinimum
                })
            );

            rewardsFees[i] = (rewardsAmount * harvestingFee) / MAX_BASIS_POINTS;
            rewardsAmount -= rewardsFees[i];

            asset.safeApprove(address(morpho), rewardsAmount);
            morpho.supply(poolTokenAddress, address(this), rewardsAmount);

            asset.safeTransfer(msg.sender, rewardsFees[i]);

            rewardsAmounts[i] = rewardsAmount;

            unchecked {
                ++i;
            }
        }
    }
}
