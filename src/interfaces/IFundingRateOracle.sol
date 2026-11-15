// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IFundingRateOracle
 * @notice Interface for on-chain perpetual futures funding rate & mark-index basis aggregation.
 */
interface IFundingRateOracle {
    struct Observation {
        uint64 timestamp;
        int64 fundingRateBps;
        uint128 markPriceX18;
        uint128 indexPriceX18;
        uint128 openInterestUsd;
    }

    struct MarketConfig {
        bytes32 marketId;
        uint32 heartbeatSeconds;
        int64 maxAbsFundingBps;
        uint16 minKeepers;
        bool active;
    }

    event ObservationPushed(
        bytes32 indexed marketId,
        address indexed keeper,
        int64 fundingRateBps,
        uint128 markPriceX18,
        uint128 indexPriceX18,
        uint128 openInterestUsd,
        uint64 timestamp
    );

    event MarketConfigured(
        bytes32 indexed marketId,
        uint32 heartbeatSeconds,
        int64 maxAbsFundingBps,
        bool active
    );

    event KeeperUpdated(address indexed keeper, bool authorized);

    function pushObservation(
        bytes32 marketId,
        int64 fundingRateBps,
        uint128 markPriceX18,
        uint128 indexPriceX18,
        uint128 openInterestUsd
    ) external;

    function getLatestFundingBps(bytes32 marketId) external view returns (int64 rateBps, uint64 updatedAt);

    function getTwapFundingBps(bytes32 marketId, uint32 windowSeconds) external view returns (int256 twapBps);

    function getBasisBps(bytes32 marketId) external view returns (int256 basisBps);

    function getAnnualizedYieldBps(bytes32 marketId, uint32 intervalsPerDay) external view returns (int256 aprBps);
}
