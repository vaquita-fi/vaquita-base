source .env

set -e

forge script script/DeployVaquitaPoolBase.s.sol:DeployVaquitaPoolBaseScript \
 --rpc-url base \
 --etherscan-api-key $ETHERSCAN_API_KEY \
 --broadcast \
 --verify