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

- mcWBTC: [0x9aca9579b797a9fa14656b3234902374c77600d3](https://etherscan.io/address/0x9aca9579b797a9fa14656b3234902374c77600d3)
- mcWETH: [0x5c17aa0730030ca7d0afc2a472bbd1d7e3ddc72d](https://etherscan.io/address/0x5c17aa0730030ca7d0afc2a472bbd1d7e3ddc72d)
- mcDAI: [0xdfe7d9322835ebd7317b5947e898780a2f97b636](https://etherscan.io/address/0xdfe7d9322835ebd7317b5947e898780a2f97b636)
- mcUSDC: [0x125e52e814d1f32d64f62677bffa28225a9283d1](https://etherscan.io/address/0x125e52e814d1f32d64f62677bffa28225a9283d1)
- mcUSDT​: [0x54dbe0f95df628217c418f423d69aa70227cf9cc](https://etherscan.io/address/0x54dbe0f95df628217c418f423d69aa70227cf9cc)
- mcCOMP: [0x1744e5d9692d86d29b54d7ac435b665c036739a6](https://etherscan.io/address/0x1744e5d9692d86d29b54d7ac435b665c036739a6)
- mcUNI: [0x0516cdc8ca5b9af576b5214075ae71914b8a863b](https://etherscan.io/address/0x0516cdc8ca5b9af576b5214075ae71914b8a863b)

#### Supply Harvest Vaults

- mchWBTC: [0xbb61dce011f8d66bcca212a501eb315a563f965e](https://etherscan.io/address/0xbb61dce011f8d66bcca212a501eb315a563f965e)
- mchWETH: [0x51bd0aca7bf4c3b4927c794bee338465f3885408](https://etherscan.io/address/0x51bd0aca7bf4c3b4927c794bee338465f3885408)
- mchDAI: [0xd9b7a4401d4e430ad8b268d72c907a5c7516317f](https://etherscan.io/address/0xd9b7a4401d4e430ad8b268d72c907a5c7516317f)
- mchUSDC: [0xaf7ddc2e19248fe4e400abc052162f146791745f](https://etherscan.io/address/0xaf7ddc2e19248fe4e400abc052162f146791745f)
- mchUSDT: [0x182971cd346b87d9f99712e3030290f4ddc664d3](https://etherscan.io/address/0x182971cd346b87d9f99712e3030290f4ddc664d3)
- mchCOMP: [0x901579c24e0ecfdb41c4b184b2ee3730975b4ad5](https://etherscan.io/address/0x901579c24e0ecfdb41c4b184b2ee3730975b4ad5)
- mchUNI: [0xafb6d25d2b0e9183fc363aff75e6a107d35bb414](https://etherscan.io/address/0xafb6d25d2b0e9183fc363aff75e6a107d35bb414)

### Morpho-Aave-V2 (Ethereum)

#### Supply Vaults

- maWBTC: [0xa59d6996bdbfaef7b64eee436e5326869c9d8399](https://etherscan.io/address/0xa59d6996bdbfaef7b64eee436e5326869c9d8399)
- maWETH: [0x762fafa0257cd3b697e0d7fd40f1f6c03f07a8ef](https://etherscan.io/address/0x762fafa0257cd3b697e0d7fd40f1f6c03f07a8ef)
- maDAI: [0x3a91d37bac30c913369e1abc8cad1c13d1ff2e98](https://etherscan.io/address/0x3a91d37bac30c913369e1abc8cad1c13d1ff2e98)
- maUSDC: [0xd45ef8c9b9431298019fc15753609db2fb101aa5](https://etherscan.io/address/0xd45ef8c9b9431298019fc15753609db2fb101aa5)
- maUSDT: [0x1926bb3977336fd376be0aee2915406a904e5870](https://etherscan.io/address/0x1926bb3977336fd376be0aee2915406a904e5870)
- maCRV: [0x963311ebb58043755a33bc3de4be8b492fda66d0](https://etherscan.io/address/0x963311ebb58043755a33bc3de4be8b492fda66d0)

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

The code is under the GNU General Public License v3.0 license, see [`LICENSE`](https://github.com/morphodao/morpho-core-v1/blob/main/LICENSE).
