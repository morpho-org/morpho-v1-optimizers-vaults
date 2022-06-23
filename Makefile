-include .env.local
.EXPORT_ALL_VARIABLES:

PROTOCOL?=compound
NETWORK?=eth-mainnet
CHAIN_ID?=1

FOUNDRY_ETH_RPC_URL?=https://${NETWORK}.g.alchemy.com/v2/${ALCHEMY_KEY}
FOUNDRY_FORK_BLOCK_NUMBER?=15013615

DAPP_REMAPPINGS?=@config/=test/${PROTOCOL}/config/${NETWORK}/

ifeq (${NETWORK}, polygon-mainnet)
  FOUNDRY_FORK_BLOCK_NUMBER=29116728
endif

ifeq (${NETWORK}, avalanche-mainnet)
  FOUNDRY_FORK_BLOCK_NUMBER=15675271
  FOUNDRY_ETH_RPC_URL=https://api.avax.network/ext/bc/C/rpc
else
endif

ifneq (, $(filter ${NETWORK}, ropsten rinkeby))
  FOUNDRY_ETH_RPC_URL=https://${NETWORK}.infura.io/v3/${INFURA_PROJECT_ID}
endif

install:
	@yarn
	@foundryup
	@git submodule update --init --recursive

	cd lib/morpho-contracts && git checkout dev && cd ../..

test:
	@echo Running all ${PROTOCOL} tests on ${NETWORK}
	@forge test -vv -c test/${PROTOCOL}

test-ansi:
	@echo Running all ${PROTOCOL} tests on ${NETWORK}
	@forge test -vv -c test/${PROTOCOL} > trace.ansi

test-html:
	@echo Running all ${PROTOCOL} tests on ${NETWORK}
	@forge test -vv -c test/${PROTOCOL} | aha --black > trace.html

contract-% c-%:
	@echo Running tests for contract $* of ${PROTOCOL} on ${NETWORK}
	@forge test -vvv -c test/${PROTOCOL}/$*.t.sol --match-contract $*

ansi-c-%:
	@echo Running tests for contract $* of ${PROTOCOL} on ${NETWORK}
	@forge test -vvv -c test/${PROTOCOL}/$*.t.sol --match-contract $* > trace.ansi

html-c-%:
	@echo Running tests for contract $* of ${PROTOCOL} on ${NETWORK}
	@forge test -vvv -c test/${PROTOCOL}/$*.t.sol --match-contract $* | aha --black > trace.html

single-% s-%:
	@echo Running single test $* of ${PROTOCOL} on ${NETWORK}
	@forge test -vvv -c test/${PROTOCOL} --match-test $*

ansi-s-%:
	@echo Running single test $* of ${PROTOCOL} on ${NETWORK}
	@forge test -vvvvv -c test/${PROTOCOL} --match-test $* > trace.ansi

html-s-%:
	@echo Running single test $* of ${PROTOCOL} on ${NETWORK}
	@forge test -vvvvv -c test/${PROTOCOL} --match-test $* | aha --black > trace.html

config:
	@forge config


.PHONY: test config common foundry
