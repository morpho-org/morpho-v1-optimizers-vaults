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
  FOUNDRY_FORK_BLOCK_NUMBER=15425110
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

build:
	@forge build --sizes --force

test-deploy:
	@echo Building transactions to deploy vaults for Morpho-${PROTOCOL} on \"${NETWORK}\"
	@forge script scripts/${PROTOCOL}/${NETWORK}/Deploy.s.sol:Deploy -vvv

deploy:
	@echo Deploying vaults for Morpho-${PROTOCOL} on \"${NETWORK}\"
	@forge script scripts/${PROTOCOL}/${NETWORK}/Deploy.s.sol:Deploy -vv --broadcast --private-key ${DEPLOYER_PRIVATE_KEY} --with-gas-price 40000000000

test:
	@echo Running all Morpho-${PROTOCOL} tests on \"${NETWORK}\" at block \"${FOUNDRY_FORK_BLOCK_NUMBER}\" with seed \"${FOUNDRY_FUZZ_SEED}\"
	@forge test --no-match-path **/live/** -vv | tee trace.ansi

gas-report:
	@echo Creating gas report for Morpho-${PROTOCOL} on \"${NETWORK}\" at block \"${FOUNDRY_FORK_BLOCK_NUMBER}\" with seed \"${FOUNDRY_FUZZ_SEED}\"
	@forge test --no-match-path **/live/** --gas-report

contract-% c-%:
	@echo Running tests for contract $* of Morpho-${PROTOCOL} on \"${NETWORK}\" at block \"${FOUNDRY_FORK_BLOCK_NUMBER}\" with seed \"${FOUNDRY_FUZZ_SEED}\"
	@forge test -vvv --match-contract $* | tee trace.ansi

single-% s-%:
	@echo Running single test $* of Morpho-${PROTOCOL} on \"${NETWORK}\" at block \"${FOUNDRY_FORK_BLOCK_NUMBER}\" with seed \"${FOUNDRY_FUZZ_SEED}\"
	@forge test -vvv --match-test $* | tee trace.ansi

config:
	@forge config

.PHONY: test config common foundry
