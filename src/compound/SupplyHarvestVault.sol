// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../interfaces/IPriceOracle.sol";

import "@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol";

import "./SupplyVaultUpgradeable.sol";

/// @title SupplyHarvestVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Compound, which can harvest accrued COMP rewards, swap them and re-supply them through Morpho-Compound.
contract SupplyHarvestVault is SupplyVaultUpgradeable {
    using SafeTransferLib for ERC20;
    using PercentageMath for uint256;
    using CompoundMath for uint256;

    /// EVENTS ///

    /// @notice Emitted when the oracle is set.
    /// @param newOracle The new oracle address.
    event OracleSet(address newOracle);

    /// @notice Emitted when the TWAP period is set.
    /// @param newTwapPeriod The new TWAP period used for the oracle.
    event TwapPeriodSet(uint256 newTwapPeriod);

    /// @notice Emitted when the fee for swapping comp for WETH is set.
    /// @param newCompSwapFee The new comp swap fee (in UniswapV3 fee unit).
    event CompSwapFeeSet(uint24 newCompSwapFee);

    /// @notice Emitted when the fee for swapping WETH for the underlying asset is set.
    /// @param newAssetSwapFee The new asset swap fee (in UniswapV3 fee unit).
    event AssetSwapFeeSet(uint24 newAssetSwapFee);

    /// @notice Emitted when the fee for harvesting is set.
    /// @param newHarvestingFee The new harvesting fee.
    event HarvestingFeeSet(uint16 newHarvestingFee);

    /// @notice Emitted when the maximum slippage for harvesting is set.
    /// @param newMaxHarvestingSlippage The new maximum slippage allowed when swapping rewards for the underlying token (in bps).
    event MaxHarvestingSlippageSet(uint16 newMaxHarvestingSlippage);

    /// ERRORS ///

    /// @notice Thrown when the TWAP period is too short.
    error TwapPeriodTooShort();

    /// @notice Thrown when the input is above the maximum basis points value (100%).
    error ExceedsMaxBasisPoints();

    /// @notice Thrown when the input is above the maximum UniswapV3 pool fee value (100%).
    error ExceedsMaxUniswapV3Fee();

    /// STRUCTS ///

    struct SwapConfig {
        uint24 compSwapFee; // The fee taken by the UniswapV3Pool for swapping COMP rewards for WETH (in UniswapV3 fee unit).
        uint24 assetSwapFee; // The fee taken by the UniswapV3Pool for swapping WETH for the underlying asset (in UniswapV3 fee unit).
        uint16 harvestingFee; // The fee taken by the claimer when harvesting the vault (in bps).
        uint16 maxHarvestingSlippage; // The maximum slippage allowed when swapping rewards for the underlying asset (in bps).
    }

    /// STORAGE ///

    uint16 public constant MAX_BASIS_POINTS = 10_000; // 100% in basis points.
    uint24 public constant MAX_UNISWAP_FEE = 1_000_000; // 100% in UniswapV3 fee units.
    ISwapRouter public constant SWAP_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); // The address of UniswapV3SwapRouter.

    bool public isEth; // Whether the underlying asset is WETH.
    address public wEth; // The address of WETH token.
    address public cComp; // The address of cCOMP token.
    address public oracle; // The oracle used to get ASSET/COMP price.
    uint256 public twapPeriod; // The TWAP period used for the oracle.
    SwapConfig public swapConfig; // The configuration of the swap on Uniswap V3.

    /// UPGRADE ///

    /// @notice Initializes the vault.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    /// @param _swapConfig The swap config to set.
    function initialize(
        address _morpho,
        address _poolToken,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit,
        address _oracle,
        uint256 _twapPeriod,
        SwapConfig memory _swapConfig,
        address _cComp
    ) external initializer {
        (isEth, wEth) = __SupplyVaultUpgradeable_init(
            _morpho,
            _poolToken,
            _name,
            _symbol,
            _initialDeposit
        );

        oracle = _oracle;
        twapPeriod = _twapPeriod;
        swapConfig = _swapConfig;

        cComp = _cComp;

        comp.safeApprove(address(SWAP_ROUTER), type(uint256).max);
    }

    /// GOVERNANCE ///

    /// @notice Sets the oracle.
    /// @param _newOracle The new oracle set.
    function setOracle(address _newOracle) external onlyOwner {
        oracle = _newOracle;
        emit OracleSet(_newOracle);
    }

    /// @notice Sets the TWAP period used for the oracle.
    /// @param _newTwapPeriod The new TWAP period set.
    function setTwapPeriod(uint256 _newTwapPeriod) external onlyOwner {
        if (_newTwapPeriod < 5 minutes) revert TwapPeriodTooShort();

        twapPeriod = _newTwapPeriod;
        emit TwapPeriodSet(_newTwapPeriod);
    }

    /// @notice Sets the fee taken by the UniswapV3Pool for swapping COMP rewards for WETH.
    /// @param _newCompSwapFee The new comp swap fee (in UniswapV3 fee unit).
    function setCompSwapFee(uint24 _newCompSwapFee) external onlyOwner {
        if (_newCompSwapFee > MAX_UNISWAP_FEE) revert ExceedsMaxUniswapV3Fee();

        swapConfig.compSwapFee = _newCompSwapFee;
        emit CompSwapFeeSet(_newCompSwapFee);
    }

    /// @notice Sets the fee taken by the UniswapV3Pool for swapping WETH for the underlying asset.
    /// @param _newAssetSwapFee The new asset swap fee (in UniswapV3 fee unit).
    function setAssetSwapFee(uint24 _newAssetSwapFee) external onlyOwner {
        if (_newAssetSwapFee > MAX_UNISWAP_FEE) revert ExceedsMaxUniswapV3Fee();

        swapConfig.assetSwapFee = _newAssetSwapFee;
        emit AssetSwapFeeSet(_newAssetSwapFee);
    }

    /// @notice Sets the fee taken by the claimer from the total amount of COMP rewards when harvesting the vault.
    /// @param _newHarvestingFee The new harvesting fee (in bps).
    function setHarvestingFee(uint16 _newHarvestingFee) external onlyOwner {
        if (_newHarvestingFee > MAX_BASIS_POINTS) revert ExceedsMaxBasisPoints();

        swapConfig.harvestingFee = _newHarvestingFee;
        emit HarvestingFeeSet(_newHarvestingFee);
    }

    /// @notice Sets the maximum slippage allowed when swapping rewards for the underlying token.
    /// @param _newMaxHarvestingSlippage The new maximum slippage allowed when swapping rewards for the underlying token (in bps).
    function setMaxHarvestingSlippage(uint16 _newMaxHarvestingSlippage) external onlyOwner {
        if (_newMaxHarvestingSlippage > MAX_BASIS_POINTS) revert ExceedsMaxBasisPoints();

        swapConfig.maxHarvestingSlippage = _newMaxHarvestingSlippage;
        emit MaxHarvestingSlippageSet(_newMaxHarvestingSlippage);
    }

    /// EXTERNAL ///

    /// @notice Harvests the vault: claims rewards from the underlying pool, swaps them for the underlying asset and supply them through Morpho.
    /// @param _maxSlippage The maximum slippage allowed for the swap (in bps).
    /// @return rewardsAmount The amount of rewards claimed, swapped then supplied through Morpho (in underlying).
    /// @return rewardsFee The amount of fees taken by the claimer (in underlying).
    function harvest(uint16 _maxSlippage)
        external
        returns (uint256 rewardsAmount, uint256 rewardsFee)
    {
        address assetMem = asset();
        address poolTokenMem = poolToken;
        address compMem = address(comp);
        SwapConfig memory swapConfigMem = swapConfig;

        address[] memory poolTokens = new address[](1);
        poolTokens[0] = poolTokenMem;
        rewardsAmount = morpho.claimRewards(poolTokens, false);

        uint256 amountOutMinimum = IPriceOracle(oracle)
        .assetToAsset(compMem, rewardsAmount, assetMem, twapPeriod)
        .percentMul(
            MAX_BASIS_POINTS - CompoundMath.min(_maxSlippage, swapConfigMem.maxHarvestingSlippage)
        );

        rewardsAmount = SWAP_ROUTER.exactInput(
            ISwapRouter.ExactInputParams({
                path: isEth
                    ? abi.encodePacked(compMem, swapConfigMem.compSwapFee, wEth)
                    : abi.encodePacked(
                        compMem,
                        swapConfigMem.compSwapFee,
                        wEth,
                        swapConfigMem.assetSwapFee,
                        assetMem
                    ),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: rewardsAmount,
                amountOutMinimum: amountOutMinimum
            })
        );

        if (swapConfigMem.harvestingFee > 0) {
            rewardsFee = rewardsAmount.percentMul(swapConfigMem.harvestingFee);
            rewardsAmount -= rewardsFee;
        }

        morpho.supply(poolTokenMem, address(this), rewardsAmount);

        if (rewardsFee > 0) ERC20(assetMem).safeTransfer(msg.sender, rewardsFee);
    }

    /// GETTERS ///

    function compSwapFee() external view returns (uint24) {
        return swapConfig.compSwapFee;
    }

    function assetSwapFee() external view returns (uint24) {
        return swapConfig.assetSwapFee;
    }

    function harvestingFee() external view returns (uint16) {
        return swapConfig.harvestingFee;
    }

    function maxHarvestingSlippage() external view returns (uint16) {
        return swapConfig.maxHarvestingSlippage;
    }
}
