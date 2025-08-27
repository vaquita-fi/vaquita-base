// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IPool
 * @author Aave
 * @notice Defines the basic interface for an Aave V3 Pool.
 */
interface IPool {
    /**
     * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
     * @param asset The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param to The address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @notice Returns the normalized income of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve's normalized income
     */
    function getReserveNormalizedIncome(address asset) external view returns (uint256);

    /**
     * @dev Returns the total supply of the token
     * @return The total supply of the token
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Returns the data of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return configuration The reserve's configuration
     * @return liquidityIndex The liquidity index, expressed in ray
     * @return currentLiquidityRate The current supply rate, expressed in ray
     * @return variableBorrowIndex The variable borrow index, expressed in ray
     * @return currentVariableBorrowRate The current variable borrow rate, expressed in ray
     * @return currentStableBorrowRate The current stable borrow rate, expressed in ray
     * @return lastUpdateTimestamp Timestamp of last update
     * @return id The id of the reserve, represents the position in the list of active reserves
     * @return aTokenAddress The aToken address
     * @return stableDebtTokenAddress The stable debt token address
     * @return variableDebtTokenAddress The variable debt token address
     * @return interestRateStrategyAddress The address of the interest rate strategy
     * @return accruedToTreasury The current treasury balance, scaled
     * @return unbacked The outstanding unbacked aTokens minted through bridging
     * @return isolationModeTotalDebt The outstanding debt borrowed against this asset in isolation mode
    */
    function getReserveData(address asset) external view returns (
        uint256 configuration,
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex,
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate,
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex,
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate,
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate,
        //timestamp of last update
        uint40 lastUpdateTimestamp,
        //the id of the reserve. Represents the position in the list of the active reserves
        uint16 id,
        //aToken address
        address aTokenAddress,
        //stableDebtToken address
        address stableDebtTokenAddress,
        //variableDebtToken address
        address variableDebtTokenAddress,
        //address of the interest rate strategy
        address interestRateStrategyAddress,
        //the current treasury balance, scaled
        uint128 accruedToTreasury,
        //the outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked,
        //the outstanding debt borrowed against this asset in isolation mode
        uint128 isolationModeTotalDebt
    );

    /**
     * @notice Borrows an `amount` of underlying asset from the reserve, receiving in return overlying aTokens.
     * @param asset The address of the underlying asset to borrow
     * @param amount The amount to be borrowed
     * @param interestRateMode The interest rate mode at which the user wants to borrow: 0 for Stable, 1 for Variable
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     */
     function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    /**
     * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
     * @param asset The address of the underlying asset to repay
     * @param amount The amount to repay
     * @param interestRateMode The interest rate mode at which the user wants to repay: 0 for Stable, 1 for Variable
     * @param onBehalfOf The address that will repay the debt
     */
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);
}

