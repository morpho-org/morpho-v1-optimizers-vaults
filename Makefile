-include .env.local
.EXPORT_ALL_VARIABLES:

PROTOCOL?=compound
NETWORK?=eth-mainnet

FOUNDRY_SRC=src/${PROTOCOL}/
FOUNDRY_TEST=test/${PROTOCOL}/
FOUNDRY_REMAPPINGS=@config/=lib/morpho-contracts/config/${NETWORK}/${PROTOCOL}/
FOUNDRY_ETH_RPC_URL?=https://${NETWORK}.g.alchemy.com/v2/${ALCHEMY_KEY}

ifeq (${NETWORK}, eth-mainnet)
  FOUNDRY_CHAIN_ID=1
  FOUNDRY_FORK_BLOCK_NUMBER=14292587
endif

ifeq (${NETWORK}, polygon-mainnet)
  FOUNDRY_CHAIN_ID=137
  FOUNDRY_FORK_BLOCK_NUMBER=22116728

  ifeq (${PROTOCOL}, aave-v3)
    FOUNDRY_FORK_BLOCK_NUMBER=29116728
  endif
endif

ifeq (${NETWORK}, avalanche-mainnet)
  FOUNDRY_CHAIN_ID=43114
  FOUNDRY_ETH_RPC_URL=https://api.avax.network/ext/bc/C/rpc
  FOUNDRY_FORK_BLOCK_NUMBER=12675271

  ifeq (${PROTOCOL}, aave-v3)
    FOUNDRY_FORK_BLOCK_NUMBER=15675271
  endif
endif


install:
	@yarn
	@foundryup
	@git submodule update --init --recursive

test:
	@echo Running all ${PROTOCOL} tests on ${NETWORK}
	@forge test -vv | tee trace.ansi

gas-report:
	@echo Creating gas report for ${PROTOCOL} on ${NETWORK} at ${FOUNDRY_FORK_BLOCK_NUMBER}
	@forge test --gas-report

contract-% c-%:
	@echo Running tests for contract $* of ${PROTOCOL} on ${NETWORK} at ${FOUNDRY_FORK_BLOCK_NUMBER}
	@forge test -vvv --match-contract $* | tee trace.ansi

single-% s-%:
	@echo Running single test $* of ${PROTOCOL} on ${NETWORK} at ${FOUNDRY_FORK_BLOCK_NUMBER}
	@forge test -vvv --match-test $* | tee trace.ansi

config:
	@forge config


.PHONY: test config common foundry
