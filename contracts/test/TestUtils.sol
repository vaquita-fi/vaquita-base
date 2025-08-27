// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "../src/interfaces/external/IPool.sol";
import {console} from "forge-std/console.sol";

abstract contract TestUtils is Test {
    uint256 public increment = 0;

    /// @notice Generates mock fees by performing a swap from tokenA to tokenB using the universal router
    function supplyCollateral(
        address whale,
        IERC20 token,
        address aavePool,
        uint256 amount
    ) public {
        // Impersonate whale and supply token to aave pool
        vm.startPrank(whale);
        token.approve(aavePool, amount);
        uint256 whaleTokenBefore = token.balanceOf(whale);
        console.log("Whale token before liquidity:", whaleTokenBefore);
        IPool(aavePool).supply(address(token), amount, whale, 0);
        uint256 whaleTokenAfter = token.balanceOf(whale);
        console.log("Whale token after liquidity:", whaleTokenAfter);
        vm.stopPrank();
    }

    /// @notice Gets the ProxyAdmin address from a TransparentUpgradeableProxy
    function _getProxyAdmin(address proxy) internal view returns (address) {
        bytes32 adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        bytes32 adminBytes = vm.load(proxy, adminSlot);
        return address(uint160(uint256(adminBytes)));
    }

    /// @notice Simulates borrowing from the Aave pool to increase liquidity index
    function borrowFunds(
        address borrower,
        IERC20 token,
        address aavePool,
        uint256 amount
    ) public {
        // Impersonate borrower
        vm.startPrank(borrower);
        // The borrower must have enough collateral supplied to the pool already
        // For testing, ensure this is the case before calling
        // interestRateMode: 2 = variable
        // referralCode: 0
        IPool(aavePool).borrow(address(token), amount, 2, 0, borrower);
        console.log("Borrowed amount:", amount);
        vm.stopPrank();
    }

    /// @notice Repays borrowed funds to the Aave pool on behalf of the borrower
    function repayFunds(
        address borrower,
        IERC20 token,
        address aavePool,
        uint256 amount
    ) public {
        vm.startPrank(borrower);
        token.approve(aavePool, amount);
        uint256 repaidAmount = IPool(aavePool).repay(address(token), amount, 2, borrower);
        console.log("Repaid amount:", repaidAmount);
        vm.stopPrank();
    }

    /// @notice Generates interest by supplying, borrowing, and repaying funds, then warps time forward by lockPeriod
    function generateInterestAndWarpToTime(
        address whale,
        IERC20 token,
        address aavePool,
        uint256 amount,
        uint256 lockPeriod
    ) public {
        uint256 halfAmount = amount / 2;
        uint256 thirdAmount = amount / 3;
        supplyCollateral(whale, token, aavePool, amount);
        borrowFunds(whale, token, aavePool, halfAmount);
        vm.warp(block.timestamp + lockPeriod);
        repayFunds(whale, token, aavePool, halfAmount + thirdAmount);
    }
} 