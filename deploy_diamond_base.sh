#!/bin/bash
# --------------------------------------------
# Deploy Audioblocks on base sepolia
# -

forge create ./contracts/Diamond.sol:Diamond --rpc-url $BASE_SEPOLIA_RPC --account deployer