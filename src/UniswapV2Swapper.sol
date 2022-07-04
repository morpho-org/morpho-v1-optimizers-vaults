// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/ISwapper.sol";

import "@solmate/utils/SafeTransferLib.sol";

/// @title UniswapV2Swapper.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice Swapper contract for Uniswap V2 DEXes.
contract UniswapV2Swapper is ISwapper {
    using SafeTransferLib for ERC20;

    /// STORAGE ///

    IUniswapV2Router02 public immutable swapRouter;
    address public immutable wrappedNativeToken;

    /// CONSTRUCTOR ///

    /// @notice Constructs contract.
    /// @param _swapRouter The swap router used for swapping assets.
    /// @param _wrappedNativeToken The wrapped native token of the given network.
    constructor(address _swapRouter, address _wrappedNativeToken) {
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
    ) external returns (uint256) {
        IUniswapV2Router02 swapRouterMem = swapRouter;
        address wrappedNativeTokenMem = wrappedNativeToken;

        address[] memory path;
        if (_tokenIn == wrappedNativeTokenMem || _tokenOut == wrappedNativeTokenMem) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = wrappedNativeTokenMem;
            path[2] = _tokenOut;
        }

        ERC20(_tokenIn).safeApprove(address(swapRouterMem), _amountIn);
        uint256[] memory amountsOut = swapRouterMem.swapExactTokensForTokens(
            _amountIn,
            0,
            path,
            _recipient,
            block.timestamp
        );

        return amountsOut[amountsOut.length - 1];
    }
}
