# Morpho Tokenized Vaults

[![Test](https://github.com/morpho-labs/morpho-contracts/actions/workflows/ci-foundry.yml/badge.svg)](https://github.com/morpho-dao/morpho-tokenized-vaults/actions/workflows/ci-foundry.yml)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://i.imgur.com/uLq5V14.png">
  <img alt="" src="https://i.imgur.com/ZiL1Lr2.png">
</picture>

---

## Morpho's vaults

Morpho's vaults represent tokenized supply positions on Morpho. Vaults are compliant to the ERC4626 standard and can be easily integrated. Please refer to the [vaults documentation](https://developers.morpho.xyz/vaults) for more information.

---

## Audits

All audits are stored in the [audits](./audits/)' folder.

---

## Deployment Addresses

### Morpho-Compound (Ethereum)

#### Supply Vaults

Not deployed yet.

#### Supply Harvest Vaults

Not deployed yet.

### Morpho-Aave-V2 (Ethereum)

#### Supply Vaults

- maWBTC: [0xd508f85f1511aaec63434e26aeb6d10be0188dc7](https://etherscan.io/address/0xd508f85f1511aaec63434e26aeb6d10be0188dc7)
- maWETH: [0x490bbbc2485e99989ba39b34802fafa58e26aba4](https://etherscan.io/address/0x490bbbc2485e99989ba39b34802fafa58e26aba4)
- maDAI: [0x36f8d0d0573ae92326827c4a82fe4ce4c244cab6](https://etherscan.io/address/0x36f8d0d0573ae92326827c4a82fe4ce4c244cab6)
- maUSDC: [0xa5269a8e31b93ff27b887b56720a25f844db0529](https://etherscan.io/address/0xa5269a8e31b93ff27b887b56720a25f844db0529)
- maUSDT: [0xafe7131a57e44f832cb2de78ade38cad644aac2f](https://etherscan.io/address/0xafe7131a57e44f832cb2de78ade38cad644aac2f)
- maCRV: [0x9dc7094530cb1bcf5442c3b9389ee386738a190c](https://etherscan.io/address/0x9dc7094530cb1bcf5442c3b9389ee386738a190c)
- Implementation: [0x5f52ab9b380fd794c77a575f1f9323dae1bd6157](https://etherscan.io/address/0x5f52ab9b380fd794c77a575f1f9323dae1bd6157)

### Common Contracts (Ethereum)

- ProxyAdmin: [0x99917ca0426fbc677e84f873fb0b726bb4799cd8](https://etherscan.io/address/0x99917ca0426fbc677e84f873fb0b726bb4799cd8)

---

## Testing with [Foundry](https://github.com/foundry-rs/foundry) 🔨

Tests are run against a forks of real networks, which allows us to interact directly with liquidity pools of Compound or Aave. Note that you need to have an RPC provider that have access to Ethereum or Polygon.

For testing, make sure `yarn` and `foundry` are installed and install dependencies (node_modules, git submodules) with:

```bash
make install
```

Alternatively, if you only want to set up

Refer to the `env.example` for the required environment variable.

To run tests on different protocols, navigate a Unix terminal to the root folder of the project and run the command of your choice:

To run every test of a specific protocol (e.g. for Morpho-Compound):

```bash
make test PROTOCOL=compound
```

or to run only a specific set of tests of a specific protocol (e.g. for Morpho-Aave V2):

```bash
make c-TestSupplyVault PROTOCOL=aave-v2
```

or to run an individual test of a specific protocol (e.g. for Morpho-Aave V2):

```bash
make s-testShouldDepositAmount PROTOCOL=aave-v2
```

For the other commands, check the [Makefile](./Makefile).

---

## Questions & Feedback

For any question or feedback you can send an email to [merlin@morpho.xyz](mailto:merlin@morpho.xyz).

---

## Licensing

The code is under the GNU AFFERO GENERAL PUBLIC LICENSE v3.0, see [`LICENSE`](./LICENSE).
