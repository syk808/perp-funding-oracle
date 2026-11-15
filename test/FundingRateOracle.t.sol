// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/FundingRateOracle.sol";
import "../src/PerpBasisVault.sol";

contract FundingRateOracleTest {
    FundingRateOracle internal oracle;
    PerpBasisVault internal vault;
    bytes32 internal constant ETH_PERP = keccak256("ETH-PERP");
    bytes32 internal constant BTC_PERP = keccak256("BTC-PERP");

    function setUp() public {
        oracle = new FundingRateOracle();
        oracle.configureMarket(ETH_PERP, 3600, 500, 1, true);
        oracle.configureMarket(BTC_PERP, 3600, 500, 1, true);
        vault = new PerpBasisVault(address(oracle), ETH_PERP, 5, -2);
    }

    function testPushAndReadObservation() public {
        setUp();
        oracle.pushObservation(ETH_PERP, 12, 3210e18, 3200e18, 50_000_000);
        (int64 rate, ) = oracle.getLatestFundingBps(ETH_PERP);
        assert(rate == 12);
        int256 basis = oracle.getBasisBps(ETH_PERP);
        assert(basis > 0);
    }

    function testClampFundingRate() public {
        setUp();
        oracle.pushObservation(ETH_PERP, 950, 3200e18, 3200e18, 25_000_000);
        (int64 rate, ) = oracle.getLatestFundingBps(ETH_PERP);
        assert(rate == 500);
    }
}
