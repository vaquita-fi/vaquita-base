# Vaquita Base

# Save to Earn Protocol on Base

Vaquita Base is an innovative **Save to Earn** protocol built on the Base blockchain, seamlessly integrated with a multi-strategy vault for yield generation. The protocol enables users to earn rewards simply by saving, creating a sustainable ecosystem where saving becomes a profitable activity.

## 🎯 Core Concept

The Save to Earn model incentivizes users to maintain their deposits over time, rewarding them for their commitment to the ecosystem. By integrating with a multi-strategy vault, users can maximize their yield through diversified yield generation strategies while maintaining the simplicity of a save-to-earn model.

## 🏗️ Architecture Overview

### Smart Contract Layer
- **VaquitaPool**: The main user-facing contract, upgradeable via OpenZeppelin's TransparentUpgradeableProxy pattern. Handles user deposits, withdrawals, reward distribution, and integrates with the multi-strategy vault. Features pausable and ownable access control for security and upgradability.
- **Multi-Strategy Vault**: Core contract managing user deposits and yield generation through diversified strategies, also upgradeable and pausable.
- **Automated Yield Management**: Handles complex yield generation across multiple strategies
- **Share-Based Accounting**: Precise tracking of user contributions and rewards using shares, ensuring fair and transparent distribution.
- **UUID-Based Deposit Tracking**: Each deposit is tracked with a unique identifier (UUID), allowing for flexible and independent management of multiple deposits per user.
- **Upgradeable & Modular**: All core contracts are upgradeable using OpenZeppelin's upgradeable contracts, allowing for future enhancements and security patches without redeployment.

### Key Features
- **Single-Token Deposits**: Users deposit USDC.e tokens, automatically deployed across multiple yield strategies
- **Multi-Strategy Yield**: Leverages diversified yield generation strategies for maximum efficiency
- **Reward Distribution**: Earn rewards based on deposit duration and amount
- **Flexible Withdrawals**: Users can withdraw their deposits and accumulated rewards at any time
- **Gas Optimization**: Efficient smart contracts designed for cost-effective operations
- **Pausable**: Both VaquitaPool and Multi-Strategy Vault can be paused by the owner for emergency response
- **Upgradeable**: Proxy pattern allows seamless upgrades and maintenance
- **EIP-2612 Permit Support**: Gasless approvals for better user experience

## 💰 Economic Model

### Save to Earn Mechanics
1. **Deposit Phase**: Users deposit USDC.e tokens into the protocol
2. **Yield Generation**: Tokens are automatically deployed across multiple yield strategies
3. **Reward Accumulation**: Users earn rewards based on:
   - Deposit amount
   - Time held in the protocol
   - Strategy performance and yields
4. **Withdrawal**: Users can withdraw their original deposit plus accumulated rewards

### Reward Sources
- **Strategy Yields**: Returns from diversified yield generation strategies
- **Protocol Rewards**: Additional incentives for long-term savers
- **Yield Optimization**: Rewards from optimized strategy allocation and rebalancing

## 🔧 Technical Implementation

### Smart Contract Features
- **VaquitaPool**: Upgradeable, pausable, and ownable. Manages user positions, rewards, and integrates with the multi-strategy vault. Uses share-based accounting and UUID tracking for deposits.
- **Multi-Strategy Vault**: Upgradeable, pausable, and ownable. Manages yield generation and interacts with external protocols.
- **UUID Tracking**: Each deposit has a unique identifier for precise management
- **Modular Design**: Extensible architecture for future enhancements
- **Security First**: Comprehensive testing and audit-ready codebase
- **Gas Efficient**: Optimized for cost-effective operations on Base
- **Upgradeable Proxy Pattern**: All main contracts use OpenZeppelin's TransparentUpgradeableProxy for safe upgrades
- **Pausable**: Emergency stop mechanism for both core contracts
- **EIP-2612 Permit**: Support for gasless token approvals

### Integration Points
- **Multi-Strategy Vault**: Direct integration with diversified yield strategies
- **Yield Protocols**: Seamless integration with various yield generation protocols
- **Strategy Management**: Automated handling of complex yield strategies
- **USDC.e**: Primary deposit token for the protocol

### Contract Configuration
- **Token**: USDC.e (Base network)
- **Yield Strategies**: Multiple diversified yield generation strategies
- **Lock Periods**: Configurable lock periods (default: 1 week)
- **Early Withdrawal Fee**: Configurable fee for early withdrawals (initially 0%)
- **Protocol Fees**: Automated fee collection for protocol sustainability

## �� Testing & Coverage

- **Comprehensive Solidity Tests**: All core logic is covered by Solidity-based tests using Foundry, including deposit/withdrawal flows, pausing, upgrades, and edge cases.
- **Upgradeable & Proxy Tests**: Deployment, initialization, and upgrade flows are thoroughly tested to ensure safe upgradability.
- **Coverage Reports**: LCOV and HTML coverage reports are generated for all contracts, including scripts, with tools to export to PDF for audit and documentation.
- **Script Coverage**: All deployment and upgrade scripts are tested for coverage, ensuring reliability of operational tooling.
- **Test Utilities**: Reusable helpers for mocking, UUID generation, and fee simulation.
- **Audit-Ready**: Codebase follows best practices for upgradeable contracts, access control, and error handling.

## �� Benefits for Users

### For Savers
- **Passive Income**: Earn rewards simply by saving
- **Liquidity Access**: Maintain access to funds while earning
- **Risk Management**: Diversified exposure through professional liquidity management
- **Transparency**: Full visibility into deposit status and rewards
- **Gas Efficiency**: EIP-2612 permit support for cost-effective transactions

### For the Ecosystem
- **Increased Capital Efficiency**: More efficient yield generation for Base ecosystem
- **User Retention**: Incentivizes long-term participation
- **Protocol Growth**: Sustainable expansion through save-to-earn mechanics

## 📊 Use Cases

### Individual Savers
- Long-term wealth accumulation
- Passive income generation
- Portfolio diversification

### DeFi Participants
- Yield generation with simplified management
- Yield optimization through diversified strategies
- Risk-adjusted returns

### Protocol Integrators
- Building on top of the save-to-earn infrastructure
- Creating additional reward mechanisms
- Developing complementary DeFi products

## ��️ Security & Audit
- **OpenZeppelin Upgradeable Contracts**: All upgradeable logic uses industry-standard libraries.
- **Pausable & Ownable**: Emergency stop and admin controls for all critical contracts.
- **Custom Errors & Events**: Gas-efficient error handling and full event logging for transparency.
- **Reentrancy Protection**: All external calls are protected against reentrancy attacks.
- **Audit-Ready**: Codebase is structured and documented for third-party security review.

## �� How to Run Tests & Generate Coverage

1. **Run all tests:**
   ```sh
   forge test
   ```
2. **Generate coverage report:**
   ```sh
   forge coverage --ir-minimum --report lcov && genhtml lcov.info --output-directory coverage-report
   ```
3. **Export coverage to PDF (all sections):**
   ```sh
   ./generate-report.sh
   ```

## 📋 Contract Verification

The contracts can be verified on BaseScan using the following command:

```bash
forge verify-contract <CONTRACT_ADDRESS> lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy --constructor-args $(cast abi-encode "constructor(address,address,bytes)" <IMPLEMENTATION_ADDRESS> <ADMIN_ADDRESS> <INIT_DATA>) --verifier basescan --verifier-url https://api.basescan.org/api --chain-id 8453 --etherscan-api-key <API_KEY>
```

---

For more details, see the contract source files and test suite.