// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

interface ISwapManager {
    function swapAssetToAsset(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _receiver
    ) external returns (uint256 amountOut_);
}
