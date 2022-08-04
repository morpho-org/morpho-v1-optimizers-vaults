// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./interfaces/ISwapper.sol";

import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title UniswapV3Swapper.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice Swapper contract for Uniswap V3 DEXes.
contract UniswapV3Swapper is ISwapper, Ownable {
    using SafeTransferLib for ERC20;

    /// EVENTS ///

    /// @notice Emitted when the fee for swapping an asset for wrapped native token (and vice-versa) is set.
    /// @param asset The address of the asset.
    /// @param newSwapFee The new swap fee (in UniswapV3 fee unit).
    event SwapFeeSet(address asset, uint24 newSwapFee);

    /// ERRORS ///

    /// @notice Thrown when the input is above the maximum UniswapV3 pool fee value (100%).
    error ExceedsMaxUniswapV3Fee();

    /// STORAGE ///

    ISwapRouter public constant SWAP_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint24 public constant MAX_UNISWAP_FEE = 100_0000; // 100% in UniswapV3 fee units.

    address public immutable wrappedNativeToken;

    mapping(address => uint24) public swapFee; // The fee taken by the selected UniswapV3Pool for the pair asset / wrapped native token (in UniswapV3 fee unit).

    /// CONSTRUCTOR ///

    /// @notice Constructs contract.
    /// @param _wrappedNativeToken The wrapped native token of the given network.
    constructor(address _wrappedNativeToken) {
        wrappedNativeToken = _wrappedNativeToken;
    }

    /// GOVERNANCE ///

    /// @notice Sets the fee taken by the selected UniswapV3Pool for the pair asset / wrapped native token.
    /// @param _asset The address of the asset.
    /// @param _newSwapFee The new swap fee (in UniswapV3 fee unit).
    function setSwapFee(address _asset, uint24 _newSwapFee) external onlyOwner {
        if (_newSwapFee > MAX_UNISWAP_FEE) revert ExceedsMaxUniswapV3Fee();

        swapFee[_asset] = _newSwapFee;
        emit SwapFeeSet(_asset, _newSwapFee);
    }

    /// EXTERNAL ///

    /// @inheritdoc ISwapper
    function executeSwap(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _recipient
    ) external returns (uint256 amountOut) {
        ERC20(_tokenIn).safeApprove(address(SWAP_ROUTER), _amountIn);

        amountOut = SWAP_ROUTER.exactInput(
            ISwapRouter.ExactInputParams({
                path: _tokenIn == wrappedNativeToken
                    ? abi.encodePacked(wrappedNativeToken, swapFee[_tokenOut], _tokenOut)
                    : _tokenOut == wrappedNativeToken
                    ? abi.encodePacked(_tokenIn, swapFee[_tokenIn], wrappedNativeToken)
                    : abi.encodePacked(
                        _tokenIn,
                        swapFee[_tokenIn],
                        wrappedNativeToken,
                        swapFee[_tokenOut],
                        _tokenOut
                    ),
                recipient: _recipient,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: 0
            })
        );

        emit Swapped(_tokenIn, _amountIn, _tokenOut, amountOut, _recipient);
    }
}
