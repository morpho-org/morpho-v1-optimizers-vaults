// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/ISwapManager.sol";
import "./interfaces/IPriceOracle.sol";

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SwapManager for Uniswap V2.
/// @notice TODO.
contract SwapManagerUniV2 is ISwapManager, IPriceOracle, Ownable {
    using SafeTransferLib for ERC20;
    using FixedPoint for *;

    /// STORAGE ///

    // TODO: update everything so that it's usable for many reward tokens and output tokens.

    uint256 public twapPeriod;
    uint256 public constant MAX_BASIS_POINTS = 10_000; // 100% in basis points.
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public blockTimestampLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    address public immutable token0;
    address public immutable token1;

    IUniswapV2Router02 public immutable swapRouter;
    IUniswapV2Pair public immutable pair;

    /// EVENTS ///

    /// @notice Emitted when a swap to Morpho tokens happens.
    /// @param _receiver The address of the receiver.
    /// @param _amountIn The amount of reward token swapped.
    /// @param _amountOut The amount of Morpho token received.
    event Swapped(address indexed _receiver, uint256 _amountIn, uint256 _amountOut);

    /// @notice Emitted when the TWAP period is set.
    /// @param _twapPeriod The new `twapPeriod`.
    event TwapPeriodSet(uint256 _twapPeriod);

    /// ERRORS ///

    /// @notice Thrown when the TWAP period is too short.
    error TwapPeriodTooShort();

    /// CONSTRUCTOR ///

    /// @notice Constructs the SwapManager contract.
    /// @param _swapRouter The swap router address.
    /// @param _twapPeriod The period for the Time-Weighted Average Price for the pair.
    constructor(address _swapRouter, uint256 _twapPeriod) {
        if (_twapPeriod < 5 minutes) revert TwapPeriodTooShort();

        //     swapRouter = IUniswapV2Router02(_swapRouter);
        //     twapPeriod = _twapPeriod;

        //     pair = IUniswapV2Pair(
        //         IUniswapV2Factory(swapRouter.factory()).getPair(, )
        //     );

        //     token0 = pair.token0();
        //     token1 = pair.token1();

        //     price0CumulativeLast = pair.price0CumulativeLast(); // Fetch the current accumulated price value (1 / 0).
        //     price1CumulativeLast = pair.price1CumulativeLast(); // Fetch the current accumulated price value (0 / 1).

        //     price0Average = FixedPoint.uq112x112(uint224(price0CumulativeLast));
        //     price1Average = FixedPoint.uq112x112(uint224(price1CumulativeLast));
    }

    /// EXTERNAL ///

    /// @notice Sets TWAP intervals.
    /// @param _twapPeriod The new `twapPeriod`.
    function setTwapIntervals(uint32 _twapPeriod) external onlyOwner {
        if (_twapPeriod < 5 minutes) revert TwapPeriodTooShort();
        twapPeriod = _twapPeriod;
        emit TwapPeriodSet(_twapPeriod);
    }

    function swapAssetToAsset(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _receiver
    ) external override returns (uint256 amountOut) {
        update();
        amountOut = assetToAsset(_tokenIn, _amountIn, _tokenOut, twapPeriod);

        uint256 expectedAmountOutMinimum; // TODO: add slippage here.

        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        // Execute the swap.
        ERC20(_tokenIn).safeApprove(address(swapRouter), _amountIn);
        uint256[] memory amountsOut = swapRouter.swapExactTokensForTokens(
            _amountIn,
            expectedAmountOutMinimum,
            path,
            _receiver,
            block.timestamp
        );

        amountOut = amountsOut[1];

        emit Swapped(_receiver, _amountIn, amountOut);
    }

    /// PUBLIC ///

    /// @notice Updates average prices on twapPeriod fixed window.
    /// @dev From https://github.com/Uniswap/v2-periphery/blob/master/contracts/examples/ExampleOracleSimple.sol
    function update() public {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint256 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint256 timeElapsed;

        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast; // Overflow is desired.
        }

        // Ensure that at least one full period has passed since the last update.
        if (timeElapsed < twapPeriod) return;

        // An overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed.
        unchecked {
            price0Average = FixedPoint.uq112x112(
                uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
            );
            price1Average = FixedPoint.uq112x112(
                uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
            );
        }

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    function assetToAsset(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        uint256 _twapPeriod
    ) public view returns (uint256) {
        if (_tokenIn == token0) return price1Average.mul(_amountIn).decode144();
        else return price0Average.mul(_amountIn).decode144();
    }
}
