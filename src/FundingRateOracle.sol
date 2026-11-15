// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IFundingRateOracle.sol";
import "./libraries/FixedPointMath.sol";

/**
 * @title FundingRateOracle
 * @notice Ring-buffer TWAP oracle for perpetual DEX funding rates and mark-index basis spreads.
 */
contract FundingRateOracle is IFundingRateOracle {
    using FixedPointMath for uint256;
    using FixedPointMath for int256;

    uint256 public constant BUFFER_CAPACITY = 256;

    address public owner;
    mapping(address => bool) public isKeeper;
    mapping(bytes32 => MarketConfig) public markets;
    mapping(bytes32 => Observation[BUFFER_CAPACITY]) internal _observations;
    mapping(bytes32 => uint256) public observationHead;
    mapping(bytes32 => uint256) public observationCount;

    error Unauthorized();
    error InactiveMarket(bytes32 marketId);
    error InvalidPrice();
    error StaleObservation(bytes32 marketId, uint64 updatedAt, uint32 heartbeat);
    error InsufficientObservations(bytes32 marketId);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyKeeper() {
        if (!isKeeper[msg.sender] && msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
        isKeeper[msg.sender] = true;
        emit KeeperUpdated(msg.sender, true);
    }

    function setKeeper(address keeper, bool authorized) external onlyOwner {
        isKeeper[keeper] = authorized;
        emit KeeperUpdated(keeper, authorized);
    }

    function configureMarket(
        bytes32 marketId,
        uint32 heartbeatSeconds,
        int64 maxAbsFundingBps,
        uint16 minKeepers,
        bool active
    ) external onlyOwner {
        markets[marketId] = MarketConfig({
            marketId: marketId,
            heartbeatSeconds: heartbeatSeconds,
            maxAbsFundingBps: maxAbsFundingBps,
            minKeepers: minKeepers,
            active: active
        });
        emit MarketConfigured(marketId, heartbeatSeconds, maxAbsFundingBps, active);
    }

    function pushObservation(
        bytes32 marketId,
        int64 fundingRateBps,
        uint128 markPriceX18,
        uint128 indexPriceX18,
        uint128 openInterestUsd
    ) external override onlyKeeper {
        MarketConfig memory cfg = markets[marketId];
        if (!cfg.active) revert InactiveMarket(marketId);
        if (markPriceX18 == 0 || indexPriceX18 == 0) revert InvalidPrice();

        int256 clamped = FixedPointMath.clampSigned(
            int256(fundingRateBps),
            -int256(cfg.maxAbsFundingBps),
            int256(cfg.maxAbsFundingBps)
        );
        int64 finalRate = int64(clamped);

        uint256 head = observationHead[marketId];
        uint64 ts = uint64(block.timestamp);

        _observations[marketId][head] = Observation({
            timestamp: ts,
            fundingRateBps: finalRate,
            markPriceX18: markPriceX18,
            indexPriceX18: indexPriceX18,
            openInterestUsd: openInterestUsd
        });

        observationHead[marketId] = (head + 1) % BUFFER_CAPACITY;
        uint256 count = observationCount[marketId];
        if (count < BUFFER_CAPACITY) {
            observationCount[marketId] = count + 1;
        }

        emit ObservationPushed(
            marketId,
            msg.sender,
            finalRate,
            markPriceX18,
            indexPriceX18,
            openInterestUsd,
            ts
        );
    }

    function getLatestObservation(bytes32 marketId) public view returns (Observation memory obs) {
        uint256 count = observationCount[marketId];
        if (count == 0) revert InsufficientObservations(marketId);
        uint256 head = observationHead[marketId];
        uint256 latestIdx = (head + BUFFER_CAPACITY - 1) % BUFFER_CAPACITY;
        obs = _observations[marketId][latestIdx];

        MarketConfig memory cfg = markets[marketId];
        if (cfg.heartbeatSeconds > 0 && block.timestamp > obs.timestamp + cfg.heartbeatSeconds) {
            revert StaleObservation(marketId, obs.timestamp, cfg.heartbeatSeconds);
        }
    }

    function getLatestFundingBps(bytes32 marketId) external view override returns (int64 rateBps, uint64 updatedAt) {
        Observation memory obs = getLatestObservation(marketId);
        return (obs.fundingRateBps, obs.timestamp);
    }

    function getBasisBps(bytes32 marketId) external view override returns (int256 basisBps) {
        Observation memory obs = getLatestObservation(marketId);
        return FixedPointMath.computeBasisBps(obs.markPriceX18, obs.indexPriceX18);
    }

    function getAnnualizedYieldBps(bytes32 marketId, uint32 intervalsPerDay) external view override returns (int256 aprBps) {
        Observation memory obs = getLatestObservation(marketId);
        return FixedPointMath.annualizeFundingBps(obs.fundingRateBps, intervalsPerDay);
    }

    function getTwapFundingBps(bytes32 marketId, uint32 windowSeconds) external view override returns (int256 twapBps) {
        uint256 count = observationCount[marketId];
        if (count == 0) revert InsufficientObservations(marketId);

        uint256 head = observationHead[marketId];
        uint256 cutoff = block.timestamp > windowSeconds ? block.timestamp - windowSeconds : 0;

        int256 weightedSum = 0;
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < count; i++) {
            uint256 idx = (head + BUFFER_CAPACITY - 1 - i) % BUFFER_CAPACITY;
            Observation memory obs = _observations[marketId][idx];
            if (obs.timestamp < cutoff && i > 0) {
                break;
            }
            uint256 weight = obs.openInterestUsd > 0 ? uint256(obs.openInterestUsd) : 1;
            weightedSum += int256(obs.fundingRateBps) * int256(weight);
            totalWeight += weight;
        }

        if (totalWeight == 0) revert InsufficientObservations(marketId);
        return weightedSum / int256(totalWeight);
    }
}
