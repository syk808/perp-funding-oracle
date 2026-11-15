// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title FixedPointMath
 * @notice Signed and unsigned fixed-point math helpers for perpetual funding rate and basis calculations.
 */
library FixedPointMath {
    int256 internal constant WAD = 1e18;
    int256 internal constant BPS = 10_000;
    uint256 internal constant UWAD = 1e18;
    uint256 internal constant UBPS = 10_000;

    error MathOverflow();
    error DivisionByZero();

    function abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    function clampSigned(int256 value, int256 minValue, int256 maxValue) internal pure returns (int256) {
        if (value < minValue) return minValue;
        if (value > maxValue) return maxValue;
        return value;
    }

    function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256) {
        if (denominator == 0) revert DivisionByZero();
        return (x * y) / denominator;
    }

    function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256) {
        if (denominator == 0) revert DivisionByZero();
        uint256 prod = x * y;
        if (prod == 0) return 0;
        return ((prod - 1) / denominator) + 1;
    }

    function computeBasisBps(uint256 markPriceX18, uint256 indexPriceX18) internal pure returns (int256) {
        if (indexPriceX18 == 0) revert DivisionByZero();
        int256 diff = int256(markPriceX18) - int256(indexPriceX18);
        return (diff * BPS) / int256(indexPriceX18);
    }

    function annualizeFundingBps(int256 intervalRateBps, uint32 intervalsPerDay) internal pure returns (int256) {
        return intervalRateBps * int256(uint256(intervalsPerDay)) * 365;
    }

    function emaSigned(int256 prevEma, int256 sample, uint256 alphaBps) internal pure returns (int256) {
        if (alphaBps > UBPS) alphaBps = UBPS;
        int256 a = int256(alphaBps);
        return (sample * a + prevEma * (BPS - a)) / BPS;
    }
}
