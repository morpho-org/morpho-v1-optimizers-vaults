// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

interface ISwapper {
    function executeSwap(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _recipient
    ) external returns (uint256);
}
