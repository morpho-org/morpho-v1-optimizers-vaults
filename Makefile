-include .env.local

export DAPP_REMAPPINGS=@config/=config/$(NETWORK)/

ifeq (${NETWORK}, avalanche-mainnet)
  export FOUNDRY_ETH_RPC_URL=https://api.avax.network/ext/bc/C/rpc
  export FOUNDRY_FORK_BLOCK_NUMBER=15675271
  export DAPP_REMAPPINGS=@config/=config/$(NETWORK)/${PROTOCOL}/
else
  export FOUNDRY_ETH_RPC_URL=https://${NETWORK}.g.alchemy.com/v2/${ALCHEMY_KEY}

  ifeq (${NETWORK}, eth-mainnet)
    export FOUNDRY_FORK_BLOCK_NUMBER=14292587
  else ifeq (${NETWORK}, polygon-mainnet)
    export FOUNDRY_FORK_BLOCK_NUMBER=29116728
    export DAPP_REMAPPINGS=@config/=config/$(NETWORK)/${PROTOCOL}/
  endif
endif

ifeq (${PROTOCOL}, aave-v3)
  export FOUNDRY_SOLC_VERSION=0.8.10
else
  export FOUNDRY_SOLC_VERSION=0.8.13
endif

test:
	@echo Running all ${PROTOCOL} tests on ${NETWORK}
	@forge test --use solc:${FOUNDRY_SOLC_VERSION} -vv -c test/${PROTOCOL}

test-ansi:
	@echo Running all ${PROTOCOL} tests on ${NETWORK}
	@forge test --use solc:${FOUNDRY_SOLC_VERSION} -vv -c test/${PROTOCOL} > trace.ansi

fuzz:
	@echo Running all ${PROTOCOL} fuzzing tests on ${NETWORK}
	@forge test --use solc:${FOUNDRY_SOLC_VERSION} -vv -c test/fuzzing/${PROTOCOL}

gas-report:
	@echo Creating gas consumption report for ${PROTOCOL} on ${NETWORK}
	@forge test --use solc:${FOUNDRY_SOLC_VERSION} -vvv -c test/${PROTOCOL} --gas-report

test-common:
	@echo Running all common tests on ${NETWORK}
	@forge test --use solc:0.8.13 -vvv -c test/common

contract-% c-%:
	@echo Running tests for contract $* of ${PROTOCOL} on ${NETWORK}
	@forge test --use solc:${FOUNDRY_SOLC_VERSION} -vvv -c test/${PROTOCOL} --match-contract $* > trace.ansi

single-% s-%:
	@echo Running single test $* of ${PROTOCOL} on ${NETWORK}
	@forge test --use solc:${FOUNDRY_SOLC_VERSION} -vvvvv -c test/${PROTOCOL} --match-test $* > trace.ansi

config:
	forge config

.PHONY: test config common
