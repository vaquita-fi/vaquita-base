source .env

set -e

forge script script/DeployVaquitaPoolBaseSepolia.s.sol:DeployVaquitaPoolBaseSepoliaScript \
 --rpc-url base-sepolia \
 --etherscan-api-key $ETHERSCAN_API_KEY \
 --broadcast \
 --verify