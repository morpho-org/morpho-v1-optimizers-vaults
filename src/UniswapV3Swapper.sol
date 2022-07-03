// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./interfaces/ISwapper.sol";

import "@solmate/utils/SafeTransferLib.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract UniswapV3Swapper is ISwapper, Ownable {
    using SafeTransferLib for ERC20;

    /// EVENTS ///

    /// @notice Emitted when the fee for swapping rewards for wrapped native token is set.
    /// @param newRewardsSwapFee The new rewards swap fee (in UniswapV3 fee unit).
    event RewardsSwapFeeSet(address rewardToken, uint24 newRewardsSwapFee);

    /// @notice Emitted when the fee for swapping wrapped native token for the underlying asset is set.
    /// @param newAssetSwapFee The new asset swap fee (in UniswapV3 fee unit).
    event AssetSwapFeeSet(address rewardToken, uint24 newAssetSwapFee);

    /// ERRORS ///

    /// @notice Thrown when the input is above the maximum UniswapV3 pool fee value (100%).
    error ExceedsMaxUniswapV3Fee();

    /// STORAGE ///

    ISwapRouter public constant SWAP_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint24 public constant MAX_UNISWAP_FEE = 1_000_000; // 100% in UniswapV3 fee units.

    address public immutable wrappedNativeToken;

    mapping(address => uint24) public rewardsSwapFee; // The fee taken by the UniswapV3Pool for swapping rewards for wrapped native token (in UniswapV3 fee unit).
    mapping(address => uint24) public assetSwapFee; // The fee taken by the UniswapV3Pool for swapping rewards for wrapped native token (in UniswapV3 fee unit).

    /// CONSTRUCTOR ///

    constructor(address _wrappedNativeToken) {
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

    /// EXTERNAL ///

    function executeSwap(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _recipient
    ) external returns (uint256) {
        ERC20(_tokenIn).safeApprove(address(SWAP_ROUTER), _amountIn);

        return
            SWAP_ROUTER.exactInput(
                ISwapRouter.ExactInputParams({
                    path: _tokenIn == wrappedNativeToken
                        ? abi.encodePacked(_tokenIn, rewardsSwapFee[_tokenIn], wrappedNativeToken)
                        : abi.encodePacked(
                            _tokenIn,
                            rewardsSwapFee[_tokenIn],
                            wrappedNativeToken,
                            assetSwapFee[_tokenIn],
                            _tokenOut
                        ),
                    recipient: _recipient,
                    deadline: block.timestamp,
                    amountIn: _amountIn,
                    amountOutMinimum: 0
                })
            );
    }
}
