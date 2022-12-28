// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapper} from "./interfaces/ISwapper.sol";

import {ERC20, SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

/// @title UniswapV2Swapper.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice Swapper contract for Uniswap V2 DEXes.
contract UniswapV2Swapper is ISwapper {
    using SafeTransferLib for ERC20;

    /// ERRORS ///

    /// @notice Thrown when the zero address is passed as input.
    error ZeroAddress();

    /// STORAGE ///

    IUniswapV2Router02 public immutable swapRouter;
    address public immutable wrappedNativeToken;

    /// CONSTRUCTOR ///

    /// @notice Constructs contract.
    /// @param _swapRouter The swap router used for swapping assets.
    /// @param _wrappedNativeToken The wrapped native token of the given network.
    constructor(address _swapRouter, address _wrappedNativeToken) {
        if (_swapRouter == address(0) || _wrappedNativeToken == address(0)) revert ZeroAddress();

        swapRouter = IUniswapV2Router02(_swapRouter);
        wrappedNativeToken = _wrappedNativeToken;
    }

    /// EXTERNAL ///

    /// @inheritdoc ISwapper
    function executeSwap(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _recipient
    ) external returns (uint256 amountOut) {
        address[] memory path;
        if (_tokenIn == wrappedNativeToken || _tokenOut == wrappedNativeToken) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = wrappedNativeToken;
            path[2] = _tokenOut;
        }

        ERC20(_tokenIn).safeApprove(address(swapRouter), _amountIn);
        uint256[] memory amountsOut = swapRouter.swapExactTokensForTokens(
            _amountIn,
            0,
            path,
            _recipient,
            block.timestamp
        );

        amountOut = amountsOut[amountsOut.length - 1];

        emit Swapped(_tokenIn, _amountIn, _tokenOut, amountOut, _recipient);
    }
}
