// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

/// @title ISwapper.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice Swapper interface for swapper contracts.
interface ISwapper {
    /// @notice Executes a swap on a DEX.
    /// @param _tokenIn The token to swap.
    /// @param _amountIn The amount of token to swap.
    /// @param _tokenOut The token to get.
    /// @param _recipient The recipient of the tokens.
    /// @return The amount of tokens received.
    function executeSwap(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _recipient
    ) external returns (uint256);
}
