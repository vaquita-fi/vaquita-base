// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title IAccessManagedMSV
 * @dev Interface for AccessManagedMSV vault that invests/deinvests using pluggable IInvestStrategy contracts
 */
interface IAccessManagedMSV is IERC4626 {
    // ERC4626 Core Functions (inherited from IERC4626)
    // These are the main deposit and withdraw functions:
    
    /**
     * @dev Deposits assets of underlying tokens into the vault and grants ownership of shares to receiver
     * @param assets The amount of underlying assets to deposit
     * @param receiver The address that will receive the vault shares
     * @return shares The amount of vault shares minted
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev Mints exactly shares vault shares to receiver by depositing assets of underlying tokens
     * @param shares The amount of vault shares to mint
     * @param receiver The address that will receive the vault shares
     * @return assets The amount of underlying assets deposited
     */
    // function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver
     * @param assets The amount of underlying assets to withdraw
     * @param receiver The address that will receive the underlying assets
     * @param owner The address that owns the vault shares to burn
     * @return shares The amount of vault shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @dev Burns exactly shares vault shares from owner and sends assets of underlying tokens to receiver
     * @param shares The amount of vault shares to burn
     * @param receiver The address that will receive the underlying assets
     * @param owner The address that owns the vault shares to burn
     * @return assets The amount of underlying assets withdrawn
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    // View Functions for Deposit/Withdraw Limits
    
    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the vault for the receiver
     * @param receiver The address that would receive the vault shares
     * @return The maximum amount of underlying assets that can be deposited
     */
    function maxDeposit(address receiver) external view returns (uint256);

    /**
     * @dev Returns the maximum amount of the vault shares that can be minted for the receiver
     * @param receiver The address that would receive the vault shares
     * @return The maximum amount of vault shares that can be minted
     */
    function maxMint(address receiver) external view returns (uint256);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance
     * @param owner The address that owns the vault shares
     * @return The maximum amount of underlying assets that can be withdrawn
     */
    function maxWithdraw(address owner) external view returns (uint256);

    /**
     * @dev Returns the maximum amount of vault shares that can be redeemed from the owner balance
     * @param owner The address that owns the vault shares
     * @return The maximum amount of vault shares that can be redeemed
     */
    function maxRedeem(address owner) external view returns (uint256);

    // Asset Information
    
    /**
     * @dev Returns the total amount of the underlying asset that is "managed" by vault
     * @return The total amount of underlying assets managed by the vault
     */
    function totalAssets() external view returns (uint256);

    // Strategy Management Functions
    
    /**
     * @dev Returns the selector used to define the role required to call forwardToStrategy
     * @param strategyIndex The index of the strategy in the _strategies array
     * @param method Id of the method to call
     * @return selector The bytes4 selector required to execute the call
     */
    function getForwardToStrategySelector(uint8 strategyIndex, uint8 method) external view returns (bytes4 selector);
}