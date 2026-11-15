// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IFundingRateOracle.sol";
import "./libraries/FixedPointMath.sol";

/**
 * @title MultiVenueAggregator
 * @notice Open-interest weighted funding rate aggregator across multiple perp DEX oracles.
 */
contract MultiVenueAggregator {
    using FixedPointMath for int256;

    struct VenueFeed {
        IFundingRateOracle oracle;
        uint96 weightBps;
        bool enabled;
    }

    address public admin;
    mapping(bytes32 => VenueFeed[]) public marketFeeds;

    event VenueFeedAdded(bytes32 indexed marketId, address indexed oracle, uint96 weightBps);

    constructor() {
        admin = msg.sender;
    }

    function addVenueFeed(bytes32 marketId, address oracleAddr, uint96 weightBps) external {
        require(msg.sender == admin, "ONLY_ADMIN");
        marketFeeds[marketId].push(VenueFeed({
            oracle: IFundingRateOracle(oracleAddr),
            weightBps: weightBps,
            enabled: true
        }));
        emit VenueFeedAdded(marketId, oracleAddr, weightBps);
    }

    function getAggregatedFundingBps(bytes32 marketId) external view returns (int256 netFundingBps) {
        VenueFeed[] memory feeds = marketFeeds[marketId];
        int256 weightedTotal = 0;
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < feeds.length; i++) {
            if (!feeds[i].enabled) continue;
            (int64 rateBps, ) = feeds[i].oracle.getLatestFundingBps(marketId);
            weightedTotal += int256(rateBps) * int256(uint256(feeds[i].weightBps));
            totalWeight += uint256(feeds[i].weightBps);
        }
        require(totalWeight > 0, "NO_ACTIVE_FEEDS");
        return weightedTotal / int256(totalWeight);
    }
}
