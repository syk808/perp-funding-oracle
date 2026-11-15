// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IFundingRateOracle.sol";
import "./libraries/FixedPointMath.sol";

/**
 * @title PerpBasisVault
 * @notice Accounting & rebalance controller for delta-neutral perpetual funding rate strategies.
 */
contract PerpBasisVault {
    using FixedPointMath for uint256;

    IFundingRateOracle public immutable oracle;
    address public strategist;
    bytes32 public activeMarketId;

    uint256 public totalAssetsUsdX18;
    uint256 public totalShares;
    int256 public minEntryFundingBps;
    int256 public exitFundingBps;
    uint256 public lastRebalanceTimestamp;

    mapping(address => uint256) public balanceOf;

    event Deposited(address indexed user, uint256 assetsX18, uint256 sharesMinted);
    event Withdrawn(address indexed user, uint256 sharesBurned, uint256 assetsX18);
    event Rebalanced(bytes32 indexed marketId, int64 fundingRateBps, int256 basisBps, uint256 timestamp);

    error NotStrategist();
    error ZeroAmount();
    error FundingBelowThreshold(int64 currentBps, int256 requiredBps);

    constructor(address oracleAddress, bytes32 initialMarketId, int256 _minEntryBps, int256 _exitBps) {
        oracle = IFundingRateOracle(oracleAddress);
        strategist = msg.sender;
        activeMarketId = initialMarketId;
        minEntryFundingBps = _minEntryBps;
        exitFundingBps = _exitBps;
    }

    function deposit(uint256 assetsX18) external returns (uint256 shares) {
        if (assetsX18 == 0) revert ZeroAmount();
        shares = totalShares == 0 ? assetsX18 : FixedPointMath.mulDivDown(assetsX18, totalShares, totalAssetsUsdX18);
        totalAssetsUsdX18 += assetsX18;
        totalShares += shares;
        balanceOf[msg.sender] += shares;
        emit Deposited(msg.sender, assetsX18, shares);
    }

    function withdraw(uint256 shares) external returns (uint256 assetsX18) {
        if (shares == 0 || shares > balanceOf[msg.sender]) revert ZeroAmount();
        assetsX18 = FixedPointMath.mulDivDown(shares, totalAssetsUsdX18, totalShares);
        balanceOf[msg.sender] -= shares;
        totalShares -= shares;
        totalAssetsUsdX18 -= assetsX18;
        emit Withdrawn(msg.sender, shares, assetsX18);
    }

    function shouldEnterBasisTrade(bytes32 marketId) public view returns (bool eligible, int256 twapBps, int256 basisBps) {
        twapBps = oracle.getTwapFundingBps(marketId, 3600);
        basisBps = oracle.getBasisBps(marketId);
        eligible = twapBps >= minEntryFundingBps && basisBps >= -25;
    }

    function executeRebalance(bytes32 targetMarketId) external {
        if (msg.sender != strategist) revert NotStrategist();
        (int64 currentRate, ) = oracle.getLatestFundingBps(targetMarketId);
        if (int256(currentRate) < minEntryFundingBps) {
            revert FundingBelowThreshold(currentRate, minEntryFundingBps);
        }
        int256 basis = oracle.getBasisBps(targetMarketId);
        activeMarketId = targetMarketId;
        lastRebalanceTimestamp = block.timestamp;
        emit Rebalanced(targetMarketId, currentRate, basis, block.timestamp);
    }
}
