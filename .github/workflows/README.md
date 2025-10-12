# GitHub Actions Workflows

## Deploy VaquitaPool Workflow

This workflow automatically deploys the VaquitaPool contract to Base Sepolia testnet or Base mainnet using the appropriate deployment scripts.

## Add Rewards Workflow

This workflow automatically adds rewards to your VaquitaPool contract. It supports both ERC20 tokens and ETH rewards with automatic token approval.

### Setup

#### Required Secrets

You need to configure the following secrets in your GitHub repository:

1. **TESTNET_PRIVATE_KEY**: Private key for Base Sepolia testnet transactions
2. **PRODUCTION_PRIVATE_KEY**: Private key for Base mainnet transactions
3. **ETHERSCAN_API_KEY**: API key for contract verification on Etherscan
4. **DEFAULT_CONTRACT_ADDRESS**: Default contract address for push-triggered rewards
5. **DEFAULT_TOKEN_ADDRESS**: Default ERC20 token address for push-triggered rewards

#### How to Add Secrets

1. Go to your GitHub repository
2. Click on "Settings" tab
3. In the left sidebar, click on "Secrets and variables" → "Actions"
4. Click "New repository secret"
5. Add each secret with the exact names listed above

### Usage

#### Deploy VaquitaPool Workflow

##### Automatic Trigger (Push Events)
The deployment workflow automatically runs when you push to `main` or `develop` branches:
- Deploys to Base Sepolia testnet by default for safety
- Uses the appropriate deployment script based on environment
- Automatically verifies contracts on Etherscan

##### Manual Trigger
1. Go to the "Actions" tab in your GitHub repository
2. Select "Deploy VaquitaPool" workflow
3. Click "Run workflow"
4. Choose the environment:
   - **testnet**: Deploys to Base Sepolia using `DeployVaquitaPoolBaseSepolia.s.sol`
   - **mainnet**: Deploys to Base mainnet using `DeployVaquitaPoolBase.s.sol`

#### Add Rewards Workflow

##### Automatic Trigger (Push Events)

The rewards workflow automatically runs when you push to `main` or `develop` branches:
- Uses default contract and token addresses from secrets
- Automatically approves ERC20 tokens before adding rewards
- Runs on testnet by default for safety

#### Manual Trigger

1. Go to the "Actions" tab in your GitHub repository
2. Select "Add Rewards" workflow
3. Click "Run workflow"
4. Fill in the required parameters:
   - **Environment**: Choose between `testnet` (Base Sepolia) or `mainnet` (Base)
   - **Contract Address**: The address of your deployed contract
   - **Token Type**: Choose between `erc20` or `eth`
   - **Token Address**: ERC20 token contract address (only for ERC20)
   - **Duration**: Duration parameter in seconds (default: `604800`)
   - **Amount**: Amount parameter (in wei for ETH, token units for ERC20)

#### Supported Functions

- **ERC20 Rewards**: `addRewards(uint256,uint256)` - Automatically approves token before calling
- **ETH Rewards**: `addRewardsETH(uint256)` - Sends ETH directly to the contract

### Security Notes

- Never commit private keys to your repository
- Use separate private keys for testnet and mainnet
- Consider using a dedicated wallet for automated transactions
- Regularly rotate your private keys
- Monitor your wallet balances and transaction history

### Network Configuration

- **Testnet (Base Sepolia)**:
  - RPC URL: `https://sepolia.base.org`
  - Chain ID: `84532`
  - Secret: `TESTNET_PRIVATE_KEY`

- **Mainnet (Base)**:
  - RPC URL: `https://mainnet.base.org`
  - Chain ID: `8453`
  - Secret: `PRODUCTION_PRIVATE_KEY`
