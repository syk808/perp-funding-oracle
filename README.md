# perp-funding-oracle

On-chain TWAP funding rate aggregator, mark-index basis spread calculator, and keeper settlement hooks for EVM perpetual futures venues.

## Architecture

- `src/interfaces/IFundingRateOracle.sol`: Standard interface for querying annualized funding bps, mark-index basis, and venue weights.
- `src/libraries/FixedPointMath.sol`: Signed wad/bps fixed-point arithmetic and clamping helpers for funding intervals.
- `src/FundingRateOracle.sol`: Multi-venue ring-buffer TWAP funding rate oracle with staleness checks and deviation guards.
- `src/PerpBasisVault.sol`: Delta-neutral funding rate harvesting vault accounting module compatible with ERC-4626 style share pricing.
- `test/FundingRateOracle.t.sol`: Foundry unit and fuzz test suite.
