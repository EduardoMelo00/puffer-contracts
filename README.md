# <h1 align="center">Puffer Contracts</h1>
[![Website][Website-badge]][Website] [![Docs][docs-badge]][docs]
  [![Discord][discord-badge]][discord] [![X][X-badge]][X] [![Foundry][foundry-badge]][foundry]

[Website-badge]: https://img.shields.io/badge/WEBSITE-8A2BE2
[Website]: https://www.puffer.fi
[X-badge]: https://img.shields.io/twitter/follow/puffer_finance
[X]: https://twitter.com/puffer_finance
[discord]: https://discord.gg/pufferfi
[docs-badge]: https://img.shields.io/badge/DOCS-8A2BE2
[docs]: https://docs.puffer.fi/
[discord-badge]: https://dcbadge.vercel.app/api/server/pufferfi?style=flat
[gha]: https://github.com/PufferFinance/PufferPool/actions
[gha-badge]: https://github.com/PufferFinance/PufferPool/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview
Stakers can deposit ETH and mint the [pufETH nLRT](https://docs.puffer.fi/protocol/nlrt#pufeth) via the PufferVault contract, which serves as a redeemable receipt for their restaked ETH. If sufficient exit liquidity is available, stakers can reclaim their ETH from the PufferVault. Over time, the redeemable amount is expected to increase from [validator tickets](https://docs.puffer.fi/protocol/validator-tickets) and restaking rewards.

In [contrast with conventional liquid staking tokens (LSTs)](https://docs.puffer.fi/protocol/nlrt#what-is-an-lst), pufETH can provide strictly more rewards for its holders. Not only does pufETH encompass PoS rewards and restaking rewards, but its value can accelerate quickly due to validator ticket sales. Furthermore, the PoS rewards for stakers are decoupled from the protocol validators' performance.

## pufETH

pufETH is implemented as a reward-bearing ERC20 token, following [ERC4626](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626/) standard and inspired by [Compound's cToken](https://docs.compound.finance/v2/ctokens/#ctokens) design for optimal DeFi compatibility. It represents a novel approach in the liquid staking domain, introducing several features that enhance stakers' rewards and interaction with DeFi protocols.

Read more about pufETH and native Liquid Restaking Tokens (nLRTs) in the [Puffer Docs](https://docs.puffer.fi/protocol/nlrt#pufeth) website.


## How pufETH Works
Stakers deposit ETH to the PufferVault contract to mint the pufETH nLRT. At the protocol's inception, pufETH's conversion rate is one-to-one, but is expected to increase over time. Assuming the protocol performs well, i.e., accrues more rewards than penalties, the amount of ETH redeemable for pufETH will increase.

### Calculating the Conversion Rate
The conversion rate can be calculated simply as:

```
conversion rate = (deposits + rewards - penalties) / pufETH supply
```
  
Where:

- deposits and pufETH supply increase proportionally as stakers deposit ETH to mint pufETH, leaving the conversion rate unaffected.

- rewards increase as [restaking operators](https://docs.puffer.fi/protocol/puffer-modules#restaking-operators) run AVSs and whenever validator tickets are minted.

- penalties accrue if validators are slashed on PoS for more than their 2 ETH collateral, which is [disincentivized behavior](https://docs.puffer.fi/protocol/validator-tickets#why--noop-incentives) and mitigated through [anti-slashing technology](https://docs.puffer.fi/technology/secure-signer). Penalties can also accrue if the restaking operator is slashed running AVSs, which is why Puffer is [restricting restaking operator participation](https://docs.puffer.fi/protocol/puffer-modules#restricting-reops) during its nascent stages.


## Contract addresses
- PufferVault (pufETH token): `0xD9A442856C234a39a81a089C06451EBAa4306a72`

For more detailed information on the contract deployments (Mainnet, Holesky, etc) and the ABIs, please check the [Deployments and ACL](https://github.com/PufferFinance/Deployments-and-ACL/blob/main/docs/deployments/) repository.


## Audits
- BlockSec: 
  - [pufETH V1](./audits/BlockSec-pufETH-v1.pdf)
  - [pufETH V2 & PufferProtocol](./audits/BlockSec%20-%20pufETHV2%20&%20PufferProtocol.pdf)
  - [Puffer L2 Staking](./audits/Blocksec%20-%20Puffer%20L2%20Staking.pdf)
  - [Fast Path Rewards](./audits/BlockSec%20-%20Fast%20Path%20Rewards.pdf)
  - [2 Step Withdrawals](./audits/BlockSec%20-%202-Step%20Withdrawals.pdf)
  - [PUFFER](./audits/BlockSec%20-%20PUFFER.pdf)
  - [ValidatorTicket upgrade & PufferRevenueDepositor](./audits/BlockSec%20-%20VT%20upgrade%20&%20PufferRevenueDepositor.pdf)
- SlowMist: 
  - [pufETH V1](./audits/SlowMist-pufETH-v1.pdf)
  - [pufETH V2 & PufferProtocol](./audits/SlowMist%20-%20pufETHV2%20&%20PufferProtocol.pdf)
  - [Puffer L2 Staking](./audits/SlowMist%20-%20Puffer%20L2%20Staking.pdf)
- Nethermind: [pufETH V2 & PufferProtocol](https://github.com/NethermindEth/PublicAuditReports/blob/main/NM0202-FINAL_PUFFER.pdf)
- Creed: [pufETH V2 & PufferProtocol](https://github.com/PufferFinance/PufferPool/blob/polish-docs/docs/audits/Creed_Puffer_Finance_Audit_April2024.pdf)
- Quantstamp: [pufETH V1](./audits/Quantstamp-pufETH-v1.pdf)
- Trail of Bits: [pufETH V2](https://github.com/trailofbits/publications/blob/master/reviews/2024-03-pufferfinance-securityreview.pdf)
- Immunefi [Boost](https://immunefi.com/boost/pufferfinance-boost/): [v1](./audits/Immunefi_Boost_pufETH_v1.pdf)

# How to run unit tests

1. Clone this repository
2. `yarn install`
3. `cd mainnet-contracts/ && yarn test:unit` or `cd l2-contracts/ yarn test:unit`


# GRANT 

## Overview

This repository contains code to upgrade an existing Puffer Vault to a new version (PufferVaultV3_Grant), introducing a grant payment system:

1. Grant Manager can set a maximum grant amount and approve addresses for grants.
2. Approved Recipients can set their preference to receive grants in ETH or WETH.
3. payGrant allows paying out ETH/WETH accordingly.
We also provide scripts for configuring roles/AccessManager and deploying/upgrading the vault, as well as tests (including fuzz tests) to validate the new logic on a mainnet fork or local environment.

## File Layout & Purpose
1 . `PufferVaultStorage.sol`

* The storage struct used by the vault.
* We appended a `mapping(address => bool) prefersWETH`; at the end of the struct to preserve upgrade storage layout.

2. `Roles.sol`

* Contains role constants like ROLE_ID_GRANT_MANAGER.
* We use these to restrict grant functions in the AccessManager.
 

3. Contracts
   1. PufferVaultV3_Grant.sol
        * Extends from PufferVaultV3 to add a grant payment system.
        * Key functions:
          *  setMaxGrantAmount(...)
          * approveGrantRecipient(...)
          *  setGrantPaymentPreference(...)
          *  payGrant(...)
  
* Uses custom errors for better clarity (NotApprovedRecipient, AmountExceedsMaxGrant, etc.).
* Recipients can store their preference for ETH or WETH; managers call payGrant which respects that preference.

## Scripts 

1. GenerateAccessManagerCalldata4.s.sol

* A Foundry script generating the multicall data to set up the `ROLE_ID_GRANT_MANAGER` for the `PufferVaultV3_Grant` contract in the AccessManager.

* You can queue and execute this data in a timelock or call AccessManager.execute(...) if you have direct admin.

* Key steps in that script:
    * `setTargetFunctionRole(pufferVaultProxy, [setMaxGrantAmount, approveGrantRecipient, payGrant], ROLE_ID_GRANT_MANAGER)`
    * `grantRole(ROLE_ID_GRANT_MANAGER, newGrantManager, 0)`
    * `DeployPufferVaultV3_Grant.s.sol`

* A Foundry script that deploys the new PufferVaultV3_Grant implementation and calls _consoleLogOrUpgradeUUPS to either log the upgrade call data or perform the upgrade on a specific network.

```javascript
  forge script ./script/DeployPufferVaultV3_Grant.s.sol:DeployPufferVaultV3_Grant --rpc-url $RPC_URL --broadcast
```

## Tests

1. PufferVaultV3Grant.t.sol

* A Foundry test that upgrades the existing PufferVault proxy to PufferVaultV3_Grant.
    * Demonstrates:
        * Setting roles in AccessManager (grant manager function selectors).
        * Approving addresses for grants, calling payGrant.
        * Basic fuzz tests (e.g., random amounts to check revert if exceeding maxGrantAmount).
