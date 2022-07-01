// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@aave/core-v3/contracts/interfaces/IPriceOracleGetter.sol";

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

    /// @notice Emitted when the fee for swapping rewards for wrapped native token is set.
    /// @param newRewardsSwapFee The new rewards swap fee (in UniswapV3 fee unit).
    event RewardsSwapFeeSet(address rewardToken, uint24 newRewardsSwapFee);

    /// @notice Emitted when the fee for swapping wrapped native token for the underlying asset is set.
    /// @param newAssetSwapFee The new asset swap fee (in UniswapV3 fee unit).
    event AssetSwapFeeSet(address rewardToken, uint24 newAssetSwapFee);

    /// @notice Emitted when the fee for harvesting is set.
    /// @param newHarvestingFee The new harvesting fee.
    event HarvestingFeeSet(uint16 newHarvestingFee);

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

    address public wrappedNativeToken; // The wrapped native token of the chain this vault is deployed on.
    uint16 public harvestingFee; // The fee taken by the claimer when harvesting the vault (in bps).
    uint16 public maxHarvestingSlippage; // The maximum slippage allowed when swapping rewards for the underlying asset (in bps).

    mapping(address => uint24) public rewardsSwapFee; // The fee taken by the UniswapV3Pool for swapping rewards for wrapped native token (in UniswapV3 fee unit).
    mapping(address => uint24) public assetSwapFee; // The fee taken by the UniswapV3Pool for swapping rewards for wrapped native token (in UniswapV3 fee unit).

    /// UPGRADE ///

    /// @notice Initializes the vault.
    /// @param _morphoAddress The address of the main Morpho contract.
    /// @param _poolTokenAddress The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    /// @param _harvestingFee The fee taken by the claimer when harvesting the vault (in bps).
    /// @param _maxHarvestingSlippage The maximum slippage allowed when swapping rewards for the underlying asset (in bps).
    function initialize(
        address _morphoAddress,
        address _poolTokenAddress,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit,
        uint16 _harvestingFee,
        uint16 _maxHarvestingSlippage,
        address _wrappedNativeToken
    ) external initializer {
        __SupplyVaultUpgradeable_init(
            _morphoAddress,
            _poolTokenAddress,
            _name,
            _symbol,
            _initialDeposit
        );

        harvestingFee = _harvestingFee;
        maxHarvestingSlippage = _maxHarvestingSlippage;
        wrappedNativeToken = _wrappedNativeToken;
    }

    /// GOVERNANCE ///

    /// @notice Sets the fee taken by the UniswapV3Pool for swapping token rewards for wrapped native token.
    /// @param _rewardToken The address of the reward token.
    /// @param _newRewardsSwapFee The new rewards swap fee (in UniswapV3 fee unit).
    function setRewardsSwapFee(address _rewardToken, uint24 _newRewardsSwapFee) external onlyOwner {
        if (_newRewardsSwapFee > MAX_UNISWAP_FEE) revert ExceedsMaxUniswapV3Fee();

        rewardsSwapFee[_rewardToken] = _newRewardsSwapFee;
        emit RewardsSwapFeeSet(_rewardToken, _newRewardsSwapFee);
    }

    /// @notice Sets the fee taken by the UniswapV3Pool for swapping wrapped native token for the underlying asset.
    /// @param _rewardToken The address of the reward token.
    /// @param _newAssetSwapFee The new asset swap fee (in UniswapV3 fee unit).
    function setAssetSwapFee(address _rewardToken, uint24 _newAssetSwapFee) external onlyOwner {
        if (_newAssetSwapFee > MAX_UNISWAP_FEE) revert ExceedsMaxUniswapV3Fee();

        assetSwapFee[_rewardToken] = _newAssetSwapFee;
        emit AssetSwapFeeSet(_rewardToken, _newAssetSwapFee);
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
    /// @return rewardTokens The addresses of reward tokens claimed.
    /// @return rewardsAmounts The amount of rewards claimed for each reward token (in underlying).
    /// @return rewardsFees The amount of fees taken by the claimer for each reward token (in underlying).
    function harvest(uint16 _maxSlippage)
        external
        returns (
            address[] memory rewardTokens,
            uint256[] memory rewardsAmounts,
            uint256[] memory rewardsFees
        )
    {
        address poolTokenAddress = address(poolToken);
        address assetAddress = asset();

        {
            address[] memory poolTokens = new address[](1);
            poolTokens[0] = poolTokenAddress;
            (rewardTokens, rewardsAmounts) = morpho.claimRewards(poolTokens, false);
        }

        IPriceOracleGetter oracle = IPriceOracleGetter(morpho.addressesProvider().getPriceOracle());

        uint256 nbRewardTokens = rewardTokens.length;
        rewardsFees = new uint256[](nbRewardTokens);

        for (uint256 i; i < nbRewardTokens; ) {
            uint256 rewardsAmount = rewardsAmounts[i];

            if (rewardsAmount > 0) {
                ERC20 rewardToken = ERC20(rewardTokens[i]);

                uint256 amountOutMinimum = rewardsAmount
                .rayMul(oracle.getAssetPrice(address(rewardToken)))
                .rayDiv(oracle.getAssetPrice(assetAddress))
                .percentMul(MAX_BASIS_POINTS - Math.min(_maxSlippage, maxHarvestingSlippage));

                rewardToken.safeApprove(address(SWAP_ROUTER), rewardsAmount);
                rewardsAmount = SWAP_ROUTER.exactInput(
                    ISwapRouter.ExactInputParams({
                        path: assetAddress == wrappedNativeToken
                            ? abi.encodePacked(
                                address(rewardToken),
                                rewardsSwapFee[address(rewardToken)],
                                wrappedNativeToken
                            )
                            : abi.encodePacked(
                                address(rewardToken),
                                rewardsSwapFee[address(rewardToken)],
                                wrappedNativeToken,
                                assetSwapFee[address(rewardToken)],
                                assetAddress
                            ),
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: rewardsAmount,
                        amountOutMinimum: amountOutMinimum
                    })
                );

                uint16 _harvestingFee = harvestingFee;
                if (_harvestingFee > 0) {
                    rewardsFees[i] = rewardsAmount.percentMul(harvestingFee);
                    rewardsAmount -= rewardsFees[i];
                }

                rewardsAmounts[i] = rewardsAmount;

                morpho.supply(poolTokenAddress, address(this), rewardsAmount);
                ERC20(assetAddress).safeTransfer(msg.sender, rewardsFees[i]);
            }

            unchecked {
                ++i;
            }
        }
    }
}
