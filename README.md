# Morpho Optimizers Vaults

[![Test](https://github.com/morpho-labs/morpho-contracts/actions/workflows/ci-foundry.yml/badge.svg)](https://github.com/morpho-dao/morpho-tokenized-vaults/actions/workflows/ci-foundry.yml)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://i.imgur.com/uLq5V14.png">
  <img alt="" src="https://i.imgur.com/ZiL1Lr2.png">
</picture>

---

## Morpho Optimizers vaults

Morpho Optimizers vaults represent tokenized supply positions on Morpho. Vaults are compliant with the ERC4626 standard and can be easily integrated. Please take a look at the [vaults documentation](https://developers-vaults.morpho.org/) for more information.

---

## Audits

Vaults' audits are accessible in the [audits](https://github.com/morpho-dao/morpho-tokenized-vaults/tree/main/audits)' folder.
All Morpho audits are accessible in the [audits section of the Morpho documentation](https://docs.morpho.org/security/audits).

---

## Deployment Addresses

### Morpho-Compound Optimizer (Ethereum)

#### Supply Vaults

- mcDAI: [0x8F88EaE3e1c01d60bccdc3DB3CBD5362Dd55d707](https://etherscan.io/address/0x8F88EaE3e1c01d60bccdc3DB3CBD5362Dd55d707)
- mcWETH: [0x676E1B7d5856f4f69e10399685e17c2299370E95](https://etherscan.io/address/0x676E1B7d5856f4f69e10399685e17c2299370E95)
- mcCOMP: [0xaA768b85eC827cCc36D882c1814bcd27ec4A8593](https://etherscan.io/address/0xaA768b85eC827cCc36D882c1814bcd27ec4A8593)
- mcUNI: [0x496da625C736a2fF122638Dc26dCf1bFdEf1778c](https://etherscan.io/address/0x496da625C736a2fF122638Dc26dCf1bFdEf1778c)
- mcUSDC: [0xba9E3b3b684719F80657af1A19DEbc3C772494a0](https://etherscan.io/address/0xba9E3b3b684719F80657af1A19DEbc3C772494a0)
- mcUSDT: [0xC2A4fBA93d4120d304c94E4fd986e0f9D213eD8A](https://etherscan.io/address/0xC2A4fBA93d4120d304c94E4fd986e0f9D213eD8A)
- mcWBTC: [0xF31AC95fe692190b9C67112d8c912bA9973944F2](https://etherscan.io/address/0xF31AC95fe692190b9C67112d8c912bA9973944F2)
- Implementation: [0x07b7319aaf04f8a28c74fd5ca3ec01aa4af66069](https://etherscan.io/address/0x07b7319aaf04f8a28c74fd5ca3ec01aa4af66069)

### Morpho-AaveV2 Optimizer (Ethereum)

#### Supply Vaults

- maWBTC: [0xd508f85f1511aaec63434e26aeb6d10be0188dc7](https://etherscan.io/address/0xd508f85f1511aaec63434e26aeb6d10be0188dc7)
- maWETH: [0x490bbbc2485e99989ba39b34802fafa58e26aba4](https://etherscan.io/address/0x490bbbc2485e99989ba39b34802fafa58e26aba4)
- maDAI: [0x36f8d0d0573ae92326827c4a82fe4ce4c244cab6](https://etherscan.io/address/0x36f8d0d0573ae92326827c4a82fe4ce4c244cab6)
- maUSDC: [0xa5269a8e31b93ff27b887b56720a25f844db0529](https://etherscan.io/address/0xa5269a8e31b93ff27b887b56720a25f844db0529)
- maUSDT: [0xafe7131a57e44f832cb2de78ade38cad644aac2f](https://etherscan.io/address/0xafe7131a57e44f832cb2de78ade38cad644aac2f)
- maCRV: [0x9dc7094530cb1bcf5442c3b9389ee386738a190c](https://etherscan.io/address/0x9dc7094530cb1bcf5442c3b9389ee386738a190c)
- Implementation: [0x86d61e37f68194b55d7590c230077e0f8607f563](https://etherscan.io/address/0x86d61e37f68194b55d7590c230077e0f8607f563)

### Common Contracts (Ethereum)

- ProxyAdmin: [0x99917ca0426fbc677e84f873fb0b726bb4799cd8](https://etherscan.io/address/0x99917ca0426fbc677e84f873fb0b726bb4799cd8)

---

## Testing with [Foundry](https://github.com/foundry-rs/foundry) 🔨

Tests are run against a fork of real networks, allowing us to interact directly with Compound or Aave liquidity pools. Note that you need an RPC provider with access to Ethereum or Polygon.

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

Or to run only a specific set of tests of a specific protocol (e.g. for Morpho-Aave V2):

```bash
make c-TestSupplyVault PROTOCOL=aave-v2
```

Or to run an individual test of a specific protocol (e.g. for Morpho-Aave V2):

```bash
make s-testShouldDepositAmount PROTOCOL=aave-v2
```

For the other commands, check the [Makefile](./Makefile).

---

## Test coverage

Test coverage is reported using [foundry](https://github.com/foundry-rs/foundry) coverage with [lcov](https://github.com/linux-test-project/lcov) report formatting (and optionally, [genhtml](https://manpages.ubuntu.com/manpages/xenial/man1/genhtml.1.html) transformer).

To generate the `lcov` report, run the following:

```bash
make coverage
```

The report is then usable either:

- via [Coverage Gutters](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters) following [this tutorial](https://mirror.xyz/devanon.eth/RrDvKPnlD-pmpuW7hQeR5wWdVjklrpOgPCOA-PJkWFU)
- via html, using `make lcov-html` to transform the report

---

## Questions & Feedback

For any question or feedback, email [merlin@morpho.org](mailto:merlin@morpho.org).

---

## Licensing

The code is under the GNU AFFERO GENERAL PUBLIC LICENSE v3.0, see [`LICENSE`](./LICENSE).
