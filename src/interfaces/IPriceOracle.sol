// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

interface IPriceOracle {
    /// @notice Given a token and its amount, return the equivalent value in another token
    /// @param tokenIn Address of an ERC20 token contract to be converted
    /// @param amountIn Amount of tokenIn to be converted
    /// @param tokenOut Address of an ERC20 token contract to convert into
    /// @param twapPeriod Number of seconds in the past to consider for the TWAP rate, if applicable
    /// @return amountOut Amount of tokenOut received for amountIn of tokenIn
    function assetToAsset(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 twapPeriod
    ) external view returns (uint256 amountOut);
}
