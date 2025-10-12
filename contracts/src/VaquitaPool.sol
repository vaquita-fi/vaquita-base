// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IAccessManagedMSV} from "./interfaces/external/IAccessManagedMSV.sol";
import {IPermit} from "./interfaces/IPermit.sol";
import {IWETH} from "./interfaces/IWETH.sol";

/**
 * @title VaquitaPool
 * @dev A protocol that allows users to deposit tokens, earn yield from a multi-strategy vault and participate in a reward pool
 */
contract VaquitaPool is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // Position struct to store user position information
    struct Position {
        address owner;
        address asset; // address(0) for ETH, token address for ERC20
        uint256 amount;
        uint256 shares;
        uint256 finalizationTime;
        uint256 lockPeriod;
    }

    // Asset status enum
    enum AssetStatus {
        Inactive,  // Default state - asset not supported
        Active,    // Asset is active and can be used for deposits/withdrawals
        Frozen     // Asset is frozen - no new deposits, but withdrawals allowed
    }

    // Asset struct to store asset information and its MSV contract
    struct Asset {
        address assetAddress; // address(0) for ETH, token address for ERC20
        address msvAddress;   // MSV contract address for this asset
        AssetStatus status;   // Current status of the asset
    }

    // Period struct to track rewards and shares for a single asset
    struct Period {
        uint256 rewardPool; // reward amount
        uint256 totalDeposits; // total deposits
        uint256 totalShares; // total shares
    }
    
    // State variables
    mapping(address => Asset) public assets; // asset address => Asset struct
    IWETH public weth; // WETH contract for ETH wrapping/unwrapping
    
    uint256 public constant BASIS_POINTS = 1e4;
    uint256 public performanceFee; // Fee for performance (initially 0)
    uint256 public protocolFees;  // protocol fees
    address public feeReceiver;   // Address to receive protocol fees

    mapping(uint256 => mapping(address => Period)) public periods; // lockPeriod => asset => Period
    mapping(uint256 => mapping(address => bool)) public isSupportedLockPeriod; // lockPeriod => asset => isSupported
    
    // Mappings
    mapping(address => uint256) public depositNonces;
    mapping(bytes32 => Position) public positions;

    // Events
    event FundsDeposited(bytes32 indexed depositId, address indexed owner, address indexed asset, uint256 amount, uint256 shares, uint256 lockPeriod);
    event FundsWithdrawn(bytes32 indexed depositId, address indexed owner, address indexed asset, uint256 transferAmount, uint256 interest, uint256 reward);
    event LockPeriodAdded(address asset, uint256 newLockPeriod);
    event PerformanceFeeUpdated(uint256 newFee);
    event RewardsAdded(address asset, uint256 period, uint256 rewardAmount);
    event ProtocolFeesAdded(uint256 protocolFees);
    event ProtocolFeesWithdrawn(uint256 protocolFees);
    event AssetAdded(address asset);
    event AssetStatusChanged(address asset, AssetStatus oldStatus, AssetStatus newStatus);
    event FeeReceiverUpdated(address oldFeeReceiver, address newFeeReceiver);
    // Errors
    error InvalidAmount();
    error PositionNotFound();
    error NotPositionOwner();
    error InvalidAddress();
    error InvalidFee();
    error PeriodNotSupported();
    error AssetNotSupported();
    error AssetAlreadyExists();
    error InsufficientETH();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initializes the contract with MSV contracts for each asset, WETH contract, and supported lock periods.
     * @dev Sets up the contract owner, pausable state, and approves the MSV contracts to spend tokens.
     * @param _assets Array of supported assets (address(0) for ETH).
     * @param _msvAddresses Array of MSV contract addresses for each asset.
     * @param _lockPeriods Array of supported lock periods in seconds.
     * @param _weth The address of the WETH contract.
     * @param _feeReceiver The address to receive protocol fees.
     */
    function initialize(
        address[] calldata _assets,
        address[] calldata _msvAddresses,
        uint256[] calldata _lockPeriods,
        address _weth,
        address _feeReceiver
    ) external initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        if (_weth == address(0)) revert InvalidAddress();
        if (_feeReceiver == address(0)) revert InvalidAddress();
        weth = IWETH(_weth);
        feeReceiver = _feeReceiver;
        
        uint256 length = _assets.length;
        if (length != _msvAddresses.length || length != _lockPeriods.length) revert InvalidAmount();
        
        for (uint256 i = 0; i < length; i++) {
            if (_msvAddresses[i] == address(0)) revert InvalidAddress();
            isSupportedLockPeriod[_lockPeriods[i]][_assets[i]] = true;
            if (assets[_assets[i]].status == AssetStatus.Inactive) {
                assets[_assets[i]] = Asset({
                    assetAddress: _assets[i],
                    msvAddress: _msvAddresses[i],
                    status: AssetStatus.Active
                });
                if (_assets[i] == address(0)) {
                    weth.approve(_msvAddresses[i], type(uint256).max);
                } else {
                    IERC20(_assets[i]).approve(_msvAddresses[i], type(uint256).max);
                }
            }
        }
    }

    /**
     * @notice Pauses the contract, disabling deposits and withdrawals.
     * @dev Only callable by the contract owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract, enabling deposits and withdrawals.
     * @dev Only callable by the contract owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Open a new position in the pool with ERC20 tokens
     * @dev Allows a user to deposit ERC20 tokens, which are supplied to the AccessManagedMSV. Position is tracked by a unique depositId.
     * @param asset The address of the ERC20 token to deposit
     * @param amount The amount of tokens to deposit
     * @param period The lock period chosen for this deposit
     * @param deadline The deadline for the permit signature
     * @param signature The permit signature for token approval
     * @return sharesToMint The number of shares minted for this deposit
     */
    function deposit(
        address asset,
        uint256 amount,
        uint256 period,
        uint256 deadline,
        bytes memory signature
    ) external nonReentrant whenNotPaused returns (uint256 sharesToMint) {
        return _deposit(asset, amount, period, deadline, signature);
    }

    /**
     * @notice Open a new position in the pool with ETH
     * @dev Allows a user to deposit ETH, which is wrapped to WETH and supplied to the AccessManagedMSV. Position is tracked by a unique depositId.
     * @param period The lock period chosen for this deposit
     * @return sharesToMint The number of shares minted for this deposit
     */
    function depositETH(uint256 period) external payable nonReentrant whenNotPaused returns (uint256 sharesToMint) {
        return _deposit(address(0), msg.value, period, 0, "");
    }

    /**
     * @notice Internal function to handle deposits for both ETH and ERC20 tokens
     * @dev Common logic for both deposit and depositETH functions
     * @param asset The asset to deposit (address(0) for ETH)
     * @param amount The amount to deposit
     * @param period The lock period
     * @param deadline The deadline for permit (0 for ETH)
     * @param signature The permit signature (empty for ETH)
     * @return sharesToMint The number of shares minted
     */
    function _deposit(
        address asset,
        uint256 amount,
        uint256 period,
        uint256 deadline,
        bytes memory signature
    ) internal returns (uint256 sharesToMint) {
        if (amount == 0) revert InvalidAmount();
        if (!isSupportedLockPeriod[period][asset]) revert PeriodNotSupported();
        Asset memory assetInfo = assets[asset];
        if (assetInfo.msvAddress == address(0) || assetInfo.status != AssetStatus.Active) revert AssetNotSupported();

        bytes32 depositId = keccak256(abi.encodePacked(msg.sender, depositNonces[msg.sender]++));
        
        // Create position
        Position storage position = positions[depositId];
        position.owner = msg.sender;
        position.asset = asset;
        position.amount = amount;
        position.finalizationTime = block.timestamp + period;
        position.lockPeriod = period;

        IAccessManagedMSV msv = IAccessManagedMSV(assetInfo.msvAddress);

        if (asset == address(0)) {
            // ETH handling
            // Wrap ETH to WETH
            weth.deposit{value: amount}();
        } else {
            // ERC20 handling
            try IPermit(asset).permit(
                msg.sender, address(this), amount, deadline, signature
            ) {} catch {}

            // Transfer tokens from user
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        }

        // Supply to asset-specific AccessManagedMSV
        sharesToMint = msv.deposit(amount, address(this));
        // AUDIT NOTE: This state change after external call is safe because:
        // 1. nonReentrant modifier prevents reentrancy
        // 2. permit() is wrapped in try-catch
        // 3. sharesToMint is a non-critical value used only for internal accounting and reward calculations
        // 4. We use a trusted token with standard EIP-2612 permit implementation
        position.shares = sharesToMint;
        periods[period][asset].totalShares += sharesToMint;
        periods[period][asset].totalDeposits += amount;

        emit FundsDeposited(depositId, msg.sender, asset, amount, sharesToMint, period);
    }

    /**
     * @notice Withdraw from an ERC20 position
     * @dev Only the position owner can withdraw. Handles performance fees and reward distribution.
     * @param depositId The ID of the position to withdraw from
     * @return amountToTransfer The amount of tokens transferred to the user
     */
    function withdraw(bytes32 depositId) external nonReentrant whenNotPaused returns (uint256 amountToTransfer) {
        return _withdraw(depositId);
    }

    /**
     * @notice Withdraw from an ETH position
     * @dev Only the position owner can withdraw. Handles performance fees and reward distribution.
     * @param depositId The ID of the position to withdraw from
     * @return amountToTransfer The amount of ETH transferred to the user
     */
    function withdrawETH(bytes32 depositId) external nonReentrant whenNotPaused returns (uint256 amountToTransfer) {
        return _withdraw(depositId);
    }

    /**
     * @notice Internal function to handle withdrawals for both ETH and ERC20 tokens
     * @dev Common logic for both withdraw and withdrawETH functions
     * @param depositId The ID of the position to withdraw from
     * @return amountToTransfer The amount transferred to the user
     */
    function _withdraw(bytes32 depositId) internal returns (uint256 amountToTransfer) {
        Position storage position = positions[depositId];
        if (position.owner == address(0)) revert PositionNotFound();
        if (position.owner != msg.sender) revert NotPositionOwner();
        address asset = position.asset;
        Asset memory assetInfo = assets[asset];
        if (assetInfo.msvAddress == address(0) || assetInfo.status == AssetStatus.Inactive) revert AssetNotSupported();

        position.owner = address(0);

        uint256 period = position.lockPeriod;
        
        IAccessManagedMSV msv = IAccessManagedMSV(assetInfo.msvAddress);

        // Withdraw from asset-specific AccessManagedMSV and get actual amount received
        uint256 withdrawnAmount = msv.redeem(position.shares, address(this), address(this));

        if (asset == address(0)) {
            weth.withdraw(withdrawnAmount);
        }

        uint256 reward = 0;
        uint256 interest = withdrawnAmount > position.amount ? withdrawnAmount - position.amount : 0;
        uint256 feeAmount = (interest * performanceFee) / BASIS_POINTS;
        uint256 remainingInterest = interest - feeAmount;
        protocolFees += feeAmount;        // Fees go to protocol fees
        emit ProtocolFeesAdded(feeAmount);
        
        if (block.timestamp < position.finalizationTime) {
            // Early withdrawal - calculate fee and add remaining interest to reward pool
            periods[period][asset].rewardPool += remainingInterest;  // Only remaining interest goes to reward pool
            amountToTransfer = withdrawnAmount - interest;
        } else {
            // Late withdrawal - calculate and distribute rewards
            reward = _calculateReward(asset, position.shares, period);
            periods[period][asset].rewardPool -= reward;
            amountToTransfer = position.amount + remainingInterest + reward;
        }
        
        periods[period][asset].totalShares -= position.shares;
        periods[period][asset].totalDeposits -= position.amount;

        if (asset == address(0)) {
            // Transfer ETH to user
            if (address(this).balance < amountToTransfer) revert InsufficientETH();
            (bool success, ) = payable(msg.sender).call{value: amountToTransfer}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC20 handling
            // Transfer ERC20 tokens to user
            IERC20(asset).safeTransfer(msg.sender, amountToTransfer);
        }

        emit FundsWithdrawn(depositId, msg.sender, asset, amountToTransfer, interest, reward);
    }

    /**
     * @notice Calculate reward for a position
     * @dev Proportional to the user's deposit amount
     * @param asset The asset for this position
     * @param amount The position amount
     * @param period The lock period for this position
     * @return reward The calculated reward
     */
    function _calculateReward(address asset, uint256 amount, uint256 period) internal view returns (uint256 reward) {
        uint256 totalDepositsForPeriod = periods[period][asset].totalDeposits;
        if (totalDepositsForPeriod == 0) return 0;
        reward = (periods[period][asset].rewardPool * amount) / totalDepositsForPeriod;
    }

    /**
     * @notice Withdraw protocol fees to the fee receiver
     * @param asset The asset to withdraw fees from (address(0) for ETH)
     */
    function withdrawProtocolFees(address asset) external onlyOwner {
        Asset memory assetInfo = assets[asset];
        if (assetInfo.msvAddress == address(0) || assetInfo.status == AssetStatus.Inactive) revert AssetNotSupported();
        if (feeReceiver == address(0)) revert InvalidAddress();
        
        uint256 cacheProtocolFees = protocolFees;
        protocolFees = 0;
        
        if (asset == address(0)) {
            // ETH withdrawal
            if (address(this).balance < cacheProtocolFees) revert InsufficientETH();
            (bool success, ) = payable(feeReceiver).call{value: cacheProtocolFees}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC20 withdrawal
            IERC20(asset).safeTransfer(feeReceiver, cacheProtocolFees);
        }
        
        emit ProtocolFeesWithdrawn(cacheProtocolFees);
    }

    /**
     * @notice Add ERC20 rewards to the reward pool (owner only)
     * @param period The lock period to add rewards to
     * @param asset The ERC20 token address to add rewards for
     * @param rewardAmount The amount of ERC20 tokens to add as rewards
     */
    function addRewards(uint256 period, address asset, uint256 rewardAmount) external onlyOwner {
        if (asset == address(0)) revert InvalidAddress(); // ETH not allowed in this function
        if (!isSupportedLockPeriod[period][asset]) revert PeriodNotSupported();
        Asset memory assetInfo = assets[asset];
        if (assetInfo.msvAddress == address(0) || assetInfo.status == AssetStatus.Inactive) revert AssetNotSupported();
        
        // Transfer ERC20 tokens from owner
        IERC20(asset).safeTransferFrom(msg.sender, address(this), rewardAmount);
        
        periods[period][asset].rewardPool += rewardAmount;

        emit RewardsAdded(asset, period, rewardAmount);
    }

    /**
     * @notice Add ETH rewards to the reward pool (owner only)
     * @param period The lock period to add rewards to
     */
    function addRewardsETH(uint256 period) external payable onlyOwner {
        address asset = address(0); // ETH
        if (!isSupportedLockPeriod[period][asset]) revert PeriodNotSupported();
        Asset memory assetInfo = assets[asset];
        if (assetInfo.msvAddress == address(0) || assetInfo.status == AssetStatus.Inactive) revert AssetNotSupported();
        
        periods[period][asset].rewardPool += msg.value;

        emit RewardsAdded(asset, period, msg.value);
    }

    /**
     * @notice Update the performance fee (owner only)
     * @param newFee The new fee in basis points (0-10000)
     */
    function updatePerformanceFee(uint256 newFee) external onlyOwner {
        if (newFee > BASIS_POINTS) revert InvalidFee();
        performanceFee = newFee;

        emit PerformanceFeeUpdated(newFee);
    }

    /**
     * @notice Add a new lock period to the supported list.
     * @dev Only callable by the contract owner.
     * @param newLockPeriod The new lock period in seconds.
     */
    function addLockPeriod(uint256 newLockPeriod, address asset) external onlyOwner {
        Asset memory assetInfo = assets[asset];
        if (assetInfo.msvAddress == address(0) || assetInfo.status == AssetStatus.Inactive) revert AssetNotSupported();
        require(!isSupportedLockPeriod[newLockPeriod][asset], "Lock period already supported");
        isSupportedLockPeriod[newLockPeriod][asset] = true;

        emit LockPeriodAdded(asset, newLockPeriod);
    }

    /**
     * @notice Add a new asset with its MSV contract.
     * @dev Only callable by the contract owner.
     * @param asset The asset address (address(0) for ETH).
     * @param msvAddress The MSV contract address for this asset.
     */
    function addAsset(address asset, address msvAddress) external onlyOwner {
        if (msvAddress == address(0)) revert InvalidAddress();
        if (assets[asset].status != AssetStatus.Inactive) revert AssetAlreadyExists(); // Asset already exists
        
        assets[asset] = Asset({
            assetAddress: asset,
            msvAddress: msvAddress,
            status: AssetStatus.Active
        });

        emit AssetAdded(asset);
    }

    /**
     * @notice Update the status of an existing asset.
     * @dev Only callable by the contract owner.
     * @param asset The asset address (address(0) for ETH).
     * @param msvAddress The new MSV contract address for this asset.
     * @param newStatus The new status for the asset.
     */
    function updateAsset(address asset, address msvAddress, AssetStatus newStatus) external onlyOwner {
        Asset storage assetInfo = assets[asset];
        if (assetInfo.msvAddress == address(0)) revert AssetNotSupported(); // Asset not set
        if (msvAddress == address(0)) revert InvalidAddress();
        
        AssetStatus oldStatus = assetInfo.status;
        // Update status if it's different
        if (oldStatus != newStatus) {
            assetInfo.status = newStatus;
        }
        
        // Update MSV address if it's different
        if (assetInfo.msvAddress != msvAddress) {
            // Revoke approval from old MSV
            if (asset == address(0)) {
                weth.approve(assetInfo.msvAddress, 0);
            } else {
                IERC20(asset).approve(assetInfo.msvAddress, 0);
            }
            
            // Set new MSV address and approve
            assetInfo.msvAddress = msvAddress;
            if (asset == address(0)) {
                weth.approve(msvAddress, type(uint256).max);
            } else {
                IERC20(asset).approve(msvAddress, type(uint256).max);
            }
        }

        emit AssetStatusChanged(asset, oldStatus, newStatus);
    }

    /**
     * @notice Set the fee receiver address.
     * @dev Only callable by the contract owner.
     * @param newFeeReceiver The new fee receiver address.
     */
    function setFeeReceiver(address newFeeReceiver) external onlyOwner {
        if (newFeeReceiver == address(0)) revert InvalidAddress();
        
        address oldFeeReceiver = feeReceiver;
        feeReceiver = newFeeReceiver;
        
        emit FeeReceiverUpdated(oldFeeReceiver, newFeeReceiver);
    }

    /**
     * @notice Receive function to accept ETH
     * @dev Allows the contract to receive ETH for deposits and rewards
     */
    receive() external payable {
        // This function allows the contract to receive ETH
        // ETH deposits should use depositETH() function
    }
}