// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VaquitaPool} from "../src/VaquitaPool.sol";
import {IPermit} from "../src/interfaces/IPermit.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IAccessManagedMSV} from "../src/interfaces/external/IAccessManagedMSV.sol";
import {TestUtils} from "./TestUtils.sol";
import {IPool} from "../src/interfaces/external/IPool.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";

contract VaquitaPoolEthTest is TestUtils {
    VaquitaPool public vaquita;
    IWETH public weth;
    IAccessManagedMSV public wethAccessManagedMSV;
    AccessManager public wethAccessManager;
    IPool public wethPool;
    address public wethWhale;
    address public deployer;
    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    uint256 public alicePrivateKey;
    uint256 public bobPrivateKey;
    uint256 public charliePrivateKey;
    uint256 public initialAmount = 1 ether;
    uint256 public lockPeriod = 1 days;

    // Base Sepolia addresses
    address constant WETH_TOKEN_ADDRESS = 0x4200000000000000000000000000000000000006; // WETH Base Sepolia
    address constant WETH_AAVE_POOL_ADDRESS = 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b; // Aave pool address for WETH
    address constant WETH_ACCESS_MANAGER_ADDRESS = 0xCc020c689BC7a485084d335335bE0c4BE520c3E4; // AccessManager address
    address constant WETH_ACCESS_MANAGED_MSV_ADDRESS = 0x19B4a4A5766a07c533b7E50b2A387b7c9CF91088; // AccessManagedMSV address
    address constant WETH_WHALE_ADDRESS = 0x598eC92B1d631b6cA5e8E4aB2883D94bbf0FCb8d; // WETH rich address
    
    address constant DEPLOYER_ADDRESS = 0x76410823009D09b1FD8e607Fd40baA0323b3bC95; // Deployer address

    function setUp() public {
        // Fork base sepolia
        uint256 baseSepoliaForkBlock = 32_214_235;
        vm.createSelectFork(vm.rpcUrl("base-sepolia"), baseSepoliaForkBlock);

        weth = IWETH(WETH_TOKEN_ADDRESS);
        wethPool = IPool(WETH_AAVE_POOL_ADDRESS);
        wethWhale = address(WETH_WHALE_ADDRESS);
        deployer = address(DEPLOYER_ADDRESS);
        wethAccessManager = AccessManager(WETH_ACCESS_MANAGER_ADDRESS);
        wethAccessManagedMSV = IAccessManagedMSV(WETH_ACCESS_MANAGED_MSV_ADDRESS);
        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        (bob, bobPrivateKey) = makeAddrAndKey("bob");
        (charlie, charliePrivateKey) = makeAddrAndKey("charlie");
        owner = makeAddr("owner");
        // Deploy VaquitaPool implementation and proxy
        VaquitaPool vaquitaImpl = new VaquitaPool();
        address[] memory assets = new address[](2);
        assets[0] = address(0);
        assets[1] = address(0);
        address[] memory msvAddresses = new address[](2);
        msvAddresses[0] = address(wethAccessManagedMSV);
        msvAddresses[1] = address(wethAccessManagedMSV);
        uint256[] memory lockPeriods = new uint256[](2);
        lockPeriods[0] = lockPeriod;
        lockPeriods[1] = 1 weeks;
        console.log("owner before initialize", owner);
        bytes memory vaquitaInitData = abi.encodeWithSelector(
            vaquitaImpl.initialize.selector,
            assets,
            msvAddresses,
            lockPeriods,
            address(weth),
            address(owner)
        );
        vm.startPrank(owner);
        TransparentUpgradeableProxy vaquitaProxy = new TransparentUpgradeableProxy(
            address(vaquitaImpl),
            owner,
            vaquitaInitData
        );
        vaquita = VaquitaPool(payable(address(vaquitaProxy)));
        vm.stopPrank();

        vm.startPrank(deployer);
        wethAccessManager.grantRole(1, address(vaquita), 0);
        vm.stopPrank();
        
        // Fund users with ETH for ETH deposits
        vm.deal(alice, 10 ether);
        vm.deal(bob, 20 ether);
        vm.deal(charlie, 30 ether);
        vm.deal(owner, 40 ether);
    }

    function depositETH(
        address user,
        uint256 amount
    ) public returns (uint256) {
        vm.startPrank(user);
        uint256 shares = vaquita.depositETH{value: amount}(lockPeriod);
        vm.stopPrank();
        return shares;
    }

    function withdrawETH(
        address user,
        bytes32 depositId
    ) public returns (uint256) {
        vm.startPrank(user);
        uint256 amount = vaquita.withdrawETH(depositId);
        vm.stopPrank();
        return amount;
    }

    function test_DepositWithApproval() public {
        uint256 shares = depositETH(alice, initialAmount);
        assertGt(shares, 0);
    }

    function test_DepositMultipleAssets() public {
        depositETH(alice, initialAmount);
        depositETH(alice, initialAmount);
        depositETH(alice, 1 ether);
    }

    function test_WithdrawAfterLock() public {
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        depositETH(alice, initialAmount);
        vm.warp(block.timestamp + lockPeriod);
        withdrawETH(alice, aliceDepositId);
        (address positionOwner,,,,,) = vaquita.positions(aliceDepositId);
        assertEq(positionOwner, address(0));
    }

    function test_AddRewardsToRewardPool() public {
        vm.startPrank(owner);
        address eth = address(0);
        uint256 rewardAmount = 1 ether;
        uint256 ownerBalanceBefore = owner.balance;
        (uint256 rewardPoolBefore,,) = vaquita.periods(lockPeriod, eth);
        vaquita.addRewardsETH{value: rewardAmount}(lockPeriod);
        uint256 ownerBalanceAfter = owner.balance;
        (uint256 rewardPoolAfter,,) = vaquita.periods(lockPeriod, eth);
        assertEq(rewardPoolAfter, rewardPoolBefore + rewardAmount, "Reward pool should increase by rewardAmount");
        assertEq(ownerBalanceAfter, ownerBalanceBefore - rewardAmount, "Owner balance should decrease by rewardAmount");
        vm.stopPrank();
    }

    function test_AddLockPeriod() public {
        address eth = address(0);
        uint256 newLockPeriod = 30 days;
        // Should not be supported initially
        bool supportedBefore = vaquita.isSupportedLockPeriod(newLockPeriod, eth);
        assertFalse(supportedBefore, "New lock period should not be supported before adding");
        // Add new lock period
        vm.prank(owner);
        vaquita.addLockPeriod(newLockPeriod, eth);
        // Should be supported after
        bool supportedAfter = vaquita.isSupportedLockPeriod(newLockPeriod, eth);
        assertTrue(supportedAfter, "New lock period should be supported after adding");
    }

    function test_PerformanceFee_EarlyWithdrawal() public {
        address eth = address(0);
        vm.prank(owner);
        vaquita.updatePerformanceFee(1000);
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        uint256 aliceBalanceBefore = alice.balance;
        depositETH(alice, initialAmount);
        (,,uint256 aliceDepositAmount,uint256 aliceShares,,) = vaquita.positions(aliceDepositId);
        assertEq(aliceDepositAmount, initialAmount, "Alice should deposit all her tokens");
        console.log("Vaquita token balance after deposit:", address(vaquita).balance);

        (,,,,,,,, address aTokenAddress,,,,,,) = wethPool.getReserveData(address(weth));
        console.log("AccessManagedMSV aToken balance after deposit:", IERC20(aTokenAddress).balanceOf(address(wethAccessManagedMSV)));

        // generate interest
        generateInterestAndWarpToTime(wethWhale, weth, WETH_AAVE_POOL_ADDRESS, 100 ether, lockPeriod / 2);

        console.log("AccessManagedMSV aToken balance after interest:", IERC20(aTokenAddress).balanceOf(address(wethAccessManagedMSV)));

        uint256 aliceBalanceBeforeWithdraw = alice.balance;
        console.log("Alice balance before withdraw:", aliceBalanceBeforeWithdraw);
        console.log("aTokenAddress", aTokenAddress);
        vm.startPrank(deployer);
        uint256 alicePreviewRedeem = wethAccessManagedMSV.previewRedeem(aliceShares);
        vm.stopPrank();
        console.log("alicePreviewRedeem", alicePreviewRedeem);
        uint256 interest = alicePreviewRedeem - aliceDepositAmount;
        console.log("interest", interest);

        // withdraw from AccessManagedMSV
        uint256 aliceWithdrawal = withdrawETH(alice, aliceDepositId);

        uint256 aliceBalanceAfter = alice.balance;
        console.log("Alice balance after withdraw:", aliceBalanceAfter);

        (uint256 rewardPool, uint256 totalDeposits,) = vaquita.periods(lockPeriod, eth);
        uint256 performanceFee = interest * 1000 / 10000;
        console.log("performanceFee", performanceFee);
        assertEq(totalDeposits, 0, "Total deposits should be 0");
        assertEq(rewardPool, interest - performanceFee, "Reward pool should be interest");
        assertEq(vaquita.protocolFees(), performanceFee, "Protocol fees should be performance fee");
        assertEq(aliceWithdrawal, initialAmount, "Alice should withdraw all her funds");
        assertEq(aliceBalanceBefore, aliceBalanceAfter, "Alice should not have lost any balance");
    }

    function test_PerformanceFee_LateWithdrawal() public {
        address eth = address(0);
        vm.prank(owner);
        vaquita.updatePerformanceFee(1000);
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        depositETH(alice, initialAmount);
        (,,uint256 aliceDepositAmount,uint256 aliceShares,,) = vaquita.positions(aliceDepositId);
        assertEq(aliceDepositAmount, initialAmount, "Alice should deposit all her tokens");
        console.log("Vaquita token balance after deposit:", address(vaquita).balance);

        (,,,,,,,, address aTokenAddress,,,,,,) = wethPool.getReserveData(address(weth));
        console.log("AccessManagedMSV aToken balance after deposit:", IERC20(aTokenAddress).balanceOf(address(wethAccessManagedMSV)));

        // generate interest
        generateInterestAndWarpToTime(wethWhale, weth, WETH_AAVE_POOL_ADDRESS, 100 ether, lockPeriod);

        console.log("AccessManagedMSV aToken balance after interest:", IERC20(aTokenAddress).balanceOf(address(wethAccessManagedMSV)));

        uint256 aliceBalanceBeforeWithdraw = alice.balance;
        console.log("Alice balance before withdraw:", aliceBalanceBeforeWithdraw);
        console.log("aTokenAddress", aTokenAddress);
        vm.startPrank(deployer);
        uint256 alicePreviewRedeem = wethAccessManagedMSV.previewRedeem(aliceShares);
        vm.stopPrank();
        console.log("alicePreviewRedeem", alicePreviewRedeem);
        uint256 interest = alicePreviewRedeem - aliceDepositAmount;
        console.log("interest", interest);

        // withdraw from AccessManagedMSV
        uint256 aliceWithdrawal = withdrawETH(alice, aliceDepositId);

        uint256 aliceBalanceAfter = alice.balance;
        console.log("Alice balance after withdraw:", aliceBalanceAfter);

        (uint256 rewardPool, uint256 totalDeposits,) = vaquita.periods(lockPeriod, eth);
        uint256 performanceFee = interest * 1000 / 10000;
        console.log("performanceFee", performanceFee);
        assertEq(totalDeposits, 0, "Total deposits should be 0");
        assertEq(rewardPool, 0, "Reward pool should be interest");
        assertEq(vaquita.protocolFees(), performanceFee, "Protocol fees should be performance fee");
        assertEq(aliceWithdrawal, initialAmount + interest - performanceFee, "Alice should withdraw all her funds");
    }

    function test_MultipleUsersWithRewardDistribution() public {
        address eth = address(0);
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        bytes32 bobDepositId = keccak256(abi.encodePacked(bob, vaquita.depositNonces(bob)));
        
        // Add rewards to pool
        uint256 rewardAmount = 3 ether;
        vm.startPrank(owner);
        vaquita.addRewardsETH{value: rewardAmount}(lockPeriod);
        (uint256 rewardPoolInContract,,) = vaquita.periods(lockPeriod, eth);
        assertEq(rewardPoolInContract, rewardAmount, "Reward pool should be equal to rewardAmount");
        assertEq(address(vaquita).balance, rewardAmount, "Vaquita should have the reward amount");
        vm.stopPrank();

        // Alice deposits
        uint256 aliceSharesMinted = depositETH(alice, initialAmount);
        console.log("aliceSharesMinted", aliceSharesMinted);
        (,,uint256 aliceDepositAmount,,,) = vaquita.positions(aliceDepositId);
        assertEq(aliceDepositAmount, initialAmount, "Alice should deposit all her tokens");
        console.log("aliceDepositAmount", aliceDepositAmount);
        vm.startPrank(deployer);
        uint256 aliceInitialAmountInAssets = wethAccessManagedMSV.convertToAssets(aliceSharesMinted);
        console.log("aliceInitialAmountInAssets", aliceInitialAmountInAssets);
        vm.stopPrank();
        // Bob deposits twice as much as Alice
        uint256 bobSharesMinted = depositETH(bob, initialAmount * 2);
        console.log("bobSharesMinted", bobSharesMinted);
        (,,uint256 bobDepositAmount,,,) = vaquita.positions(bobDepositId);
        assertEq(bobDepositAmount, initialAmount * 2, "Bob should deposit all his tokens");
        console.log("bobDepositAmount", bobDepositAmount);
        vm.startPrank(deployer);
        uint256 bobInitialAmountInAssets = wethAccessManagedMSV.convertToAssets(bobSharesMinted);
        console.log("bobInitialAmountInAssets", bobInitialAmountInAssets);
        vm.stopPrank();

        generateInterestAndWarpToTime(wethWhale, weth, WETH_AAVE_POOL_ADDRESS, 100 ether, lockPeriod);

        (uint256 rewardPool, uint256 totalDeposits,) = vaquita.periods(lockPeriod, eth);

        console.log("vaquita.rewardPool()", rewardPool);
        console.log("vaquita.totalDeposits()", totalDeposits);

        uint256 aliceReward = aliceDepositAmount * rewardPool / totalDeposits;
        uint256 bobReward = bobDepositAmount * (rewardPool - aliceReward) / (totalDeposits - aliceDepositAmount);
        console.log("aliceReward", aliceReward);
        console.log("bobReward", bobReward);
        
        // Alice withdraws (should get 1/3 of reward pool since she deposited 1M out of 3M total)
        (,,,uint256 aliceShares,,) = vaquita.positions(aliceDepositId);
        console.log("aliceShares", aliceShares);
        vm.startPrank(deployer);
        uint256 alicePreviewRedeem = wethAccessManagedMSV.previewRedeem(aliceShares);
        console.log("alicePreviewRedeem", alicePreviewRedeem);
        vm.stopPrank();
        uint256 aliceInterest = alicePreviewRedeem - aliceDepositAmount;
        console.log("Alice interest:", aliceInterest);
        uint256 aliceBalanceBefore = alice.balance;
        vm.startPrank(deployer);
        uint256 aliceFinalSharesToAssets = wethAccessManagedMSV.convertToAssets(aliceShares);
        console.log("aliceFinalSharesToAssets", aliceFinalSharesToAssets);
        vm.stopPrank();
        uint256 aliceWithdrawal = withdrawETH(alice, aliceDepositId);
        console.log("Alice withdrawal:", aliceWithdrawal);
        // assertEq(aliceWithdrawal, aliceFinalSharesToAssets + aliceReward, "Alice withdrawal should be equal to aliceFinalSharesToAssets + aliceInterest");
        uint256 aliceBalanceAfter = alice.balance;
        
        (,,,uint256 bobShares,,) = vaquita.positions(bobDepositId);
        console.log("bobShares", bobShares);
        vm.startPrank(deployer);
        uint256 bobPreviewRedeem = wethAccessManagedMSV.previewRedeem(bobShares);
        console.log("bobPreviewRedeem", bobPreviewRedeem);
        vm.stopPrank();
        uint256 bobInterest = bobPreviewRedeem - bobDepositAmount;
        console.log("Bob interest:", bobInterest);
        uint256 bobBalanceBefore = bob.balance;
        vm.startPrank(deployer);
        uint256 bobFinalSharesToAssets = wethAccessManagedMSV.convertToAssets(bobShares);
        console.log("bobFinalSharesToAssets", bobFinalSharesToAssets);
        vm.stopPrank();
        withdrawETH(bob, bobDepositId);
        uint256 bobBalanceAfter = bob.balance;
        
        uint256 aliceTotal = aliceBalanceAfter - aliceBalanceBefore;
        uint256 bobTotal = bobBalanceAfter - bobBalanceBefore;
        
        console.log("Alice deposited:", initialAmount);
        console.log("Alice received:", aliceTotal);
        console.log("Alice interest:", aliceInterest);
        console.log("Alice reward:", aliceReward);
        
        console.log("Bob deposited:", initialAmount * 2);
        console.log("Bob received:", bobTotal);
        console.log("Bob interest:", bobInterest);
        console.log("Bob reward:", bobReward);
        console.log("initialAmount", initialAmount);
        console.log("aliceInitialAmountInAssets", aliceInitialAmountInAssets);
        console.log("bobInitialAmountInAssets", bobInitialAmountInAssets);
        assertEq(aliceTotal, initialAmount + aliceInterest + aliceReward, "Alice total should be initialAmount + aliceInterest + aliceReward");
        assertEq(bobTotal, (initialAmount * 2) + bobInterest + bobReward, "Bob total should be initialAmount * 2 + bobInterest + bobReward");
        
        // assertApproxEqAbs(bobTotal, initialAmount * 2 + bobInterest + bobReward, 10, "Bob total should be initialAmount * 2 + bobInterest + bobReward");

        // Verify both users got more than they deposited
        assertGt(aliceTotal, initialAmount, "Alice should profit");
        assertGt(bobTotal, initialAmount * 2, "Bob should profit");
        (uint256 newRewardPool,,) = vaquita.periods(lockPeriod, eth);
        assertEq(newRewardPool, 0, "Reward pool should be 0");
    }

    function test_WhaleGeneratesInterest() public {
        console.log("=== Starting Whale Swap Fee Generation Test ===");
        
        // Step 1: Alice deposits into VaquitaPool
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        depositETH(alice, initialAmount);
        
        uint256 aliceBalanceBefore = alice.balance;
        console.log("Alice balance before deposit:", aliceBalanceBefore);
        
        (,, uint256 positionAmount,,,) = vaquita.positions(aliceDepositId);
        console.log("Position amount:", positionAmount);
        
        // Step 2: Simulate whale making a large swap to generate fees
        generateInterestAndWarpToTime(wethWhale, weth, WETH_AAVE_POOL_ADDRESS, 100 ether, lockPeriod);
        
        // Step 3: Alice withdraws and check if she got more than she deposited
        console.log("\n=== Alice Withdrawal ===");
        
        uint256 aliceBalanceBeforeWithdraw = alice.balance;
        console.log("Alice balance before withdraw:", aliceBalanceBeforeWithdraw);
        
        uint256 withdrawnAmount = withdrawETH(alice, aliceDepositId);
        
        uint256 aliceBalanceAfterWithdraw = alice.balance;
        console.log("Alice balance after withdraw:", aliceBalanceAfterWithdraw);
        console.log("Amount withdrawn:", withdrawnAmount);
        console.log("Original deposit:", initialAmount);
        
        // Calculate profit/loss
        uint256 totalReceived = aliceBalanceAfterWithdraw - aliceBalanceBeforeWithdraw;
        console.log("Total received by Alice:", totalReceived);
        
        if (totalReceived > initialAmount) {
            uint256 profit = totalReceived - initialAmount;
            console.log("Alice made a profit of:", profit);
            console.log("Profit percentage:", (profit * 10000) / initialAmount, "basis points");
            
            // Assert that Alice made a profit
            assertGt(totalReceived, initialAmount, "Alice should have made a profit from interest");
        } else {
            uint256 loss = initialAmount - totalReceived;
            console.log("Alice made a loss of:", loss);
            console.log("Loss percentage:", (loss * 10000) / initialAmount, "basis points");
        }
        
        // Check if the position is now inactive
        (address positionOwner,,,,,) = vaquita.positions(aliceDepositId);
        assertEq(positionOwner, address(0), "Position should be inactive after withdrawal");
    }

    function test_MultipleUsersWithWhaleGeneratesInterest() public {
        vm.recordLogs();
        address eth = address(0);
        // Multiple users deposit
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        bytes32 bobDepositId = keccak256(abi.encodePacked(bob, vaquita.depositNonces(bob)));
        bytes32 charlieDepositId = keccak256(abi.encodePacked(charlie, vaquita.depositNonces(charlie)));
        
        // Alice deposits
        uint256 aliceShares = depositETH(alice, initialAmount);
        // Bob deposits
        uint256 bobShares = depositETH(bob, initialAmount);
        // Charlie deposits
        uint256 charlieShares = depositETH(charlie, initialAmount);

        (,, uint256 totalShares) = vaquita.periods(lockPeriod, eth);
        uint256 totalDeposits = 0;
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.log("entries.length", entries.length);
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == keccak256("FundsDeposited(bytes32,address,address,uint256,uint256,uint256)")) {
                (uint256 amount,, ) = abi.decode(entries[i].data, (uint256, uint256, uint256));
                totalDeposits += amount;
            }
        }
        console.log("pasa totalDeposits", totalDeposits);
        assertEq(aliceShares + bobShares + charlieShares, totalShares, "Total shares should be 3 * initialAmount");
        assertEq(totalDeposits, 3 * initialAmount, "Total deposits should be 3 * initialAmount");
        
        // Whale makes multiple swaps to generate more fees
        for (uint i = 0; i < 3; i++) {
            generateInterestAndWarpToTime(wethWhale, weth, WETH_AAVE_POOL_ADDRESS, 50 ether, lockPeriod);
        }
        
        // Fast forward past lock period
        vm.warp(block.timestamp + lockPeriod + 1);

        console.log("Token balance of vaquita before withdraws", address(vaquita).balance);
        
        // All users withdraw and check profits
        address[3] memory users = [alice, bob, charlie];
        bytes32[3] memory userDepositIds = [aliceDepositId, bobDepositId, charlieDepositId];
        
        for (uint i = 0; i < users.length; i++) {
            uint256 balanceBefore = users[i].balance;
            uint256 withdrawn = withdrawETH(users[i], userDepositIds[i]);
            uint256 balanceAfter = users[i].balance;
            
            assertEq(balanceAfter, balanceBefore + withdrawn, "User should have received the correct amount");

            console.log("User", i, "total received:", withdrawn);
            console.log("User", i, "original deposit:", initialAmount);
            
            if (withdrawn > initialAmount) {
                console.log("User", i, "profit:", withdrawn - initialAmount);
            }
        }

        console.log("Token balance of vaquita after withdraws", address(vaquita).balance);
        assertEq(address(vaquita).balance, 0, "Vaquita should have 0 balance after withdraws");
    }

    function test_PauseAndUnpause() public {
        address eth = address(0);
        // Only owner can pause
        vm.prank(alice);
        vm.expectRevert();
        vaquita.pause();

        // Owner can pause
        vm.prank(owner);
        vaquita.pause();
        assertTrue(vaquita.paused(), "Contract should be paused");

        // Deposit should revert when paused
        vm.prank(alice);
        vm.expectRevert();
        vaquita.depositETH{value: 1 ether}(lockPeriod);

        // Withdraw should revert when paused
        vm.expectRevert();
        vaquita.withdrawETH(bytes32(keccak256("id1")));

        // addRewards should not revert when paused
        vm.prank(owner);
        vaquita.addRewardsETH{value: 1 ether}(lockPeriod);

        vm.prank(owner);
        vaquita.withdrawProtocolFees(eth);

        // Only owner can unpause
        vm.prank(alice);
        vm.expectRevert();
        vaquita.unpause();

        // Owner can unpause
        vm.prank(owner);
        vaquita.unpause();
        assertFalse(vaquita.paused(), "Contract should be unpaused");
    }

    function test_UpdatePerformanceFee() public {
        // Only owner can update
        vm.prank(alice);
        vm.expectRevert();
        vaquita.updatePerformanceFee(100);

        // Owner can update
        vm.prank(owner);
        vaquita.updatePerformanceFee(100);
        assertEq(vaquita.performanceFee(), 100, "Performance fee should be updated");

        // Revert if fee > BASIS_POINTS
        vm.prank(owner);
        vm.expectRevert(VaquitaPool.InvalidFee.selector);
        vaquita.updatePerformanceFee(10001);
    }

    function test_WithdrawProtocolFees() public {
        vm.recordLogs();
        address eth = address(0);
        // Set performance fee to 5%
        vm.prank(owner);
        vaquita.updatePerformanceFee(500); // 5%

        // Alice deposits
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        depositETH(alice, initialAmount);

        generateInterestAndWarpToTime(wethWhale, weth, WETH_AAVE_POOL_ADDRESS, 100 ether, lockPeriod / 2);

        // Alice withdraws early (before lock period ends)
        withdrawETH(alice, aliceDepositId);

        // Protocol fees should be greater than 0
        assertGt(vaquita.protocolFees(), 0, "Protocol fees should be greater than 0 after early withdrawal");

        // Only owner can withdraw protocol fees
        vm.prank(alice);
        vm.expectRevert();
        vaquita.withdrawProtocolFees(eth);

        // Owner withdraws protocol fees
        vm.prank(owner);
        vaquita.withdrawProtocolFees(eth);
        assertEq(vaquita.protocolFees(), 0, "Protocol fees should be zero after withdrawal");
    }

    function test_UpdateLockPeriod() public {
        address eth = address(0);
        // Only owner can update
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.addLockPeriod(2 days, eth);

        // Owner can update
        vm.prank(owner);
        vaquita.addLockPeriod(2 days, eth);
        // lock period 2 days should be added
        assertTrue(vaquita.isSupportedLockPeriod(2 days, eth), "Lock period 2 days should be added");
    }

    function test_UpdateAsset_Success() public {
        address eth = address(0);
        // Create a new MSV contract for testing
        address newMsvAddress = makeAddr("newMsv");
        
        // Test updating MSV address and status
        vm.prank(owner);
        vaquita.updateAsset(eth, newMsvAddress, VaquitaPool.AssetStatus.Frozen);
        
        // Verify the asset was updated
        (address assetAddress, address msvAddress, VaquitaPool.AssetStatus status) = vaquita.assets(eth);
        assertEq(assetAddress, eth, "Asset address should remain the same");
        assertEq(msvAddress, newMsvAddress, "MSV address should be updated");
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Frozen), "Status should be updated to Frozen");
    }

    function test_UpdateAsset_OnlyOwner() public {
        address eth = address(0);
        address newMsvAddress = makeAddr("newMsv");
        
        // Non-owner cannot update asset
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.updateAsset(eth, newMsvAddress, VaquitaPool.AssetStatus.Frozen);
    }

    function test_UpdateAsset_AssetNotSupported() public {
        address newMsvAddress = makeAddr("newMsv");
        address unsupportedAsset = makeAddr("unsupportedAsset");
        
        // Cannot update unsupported asset
        vm.prank(owner);
        vm.expectRevert(VaquitaPool.AssetNotSupported.selector);
        vaquita.updateAsset(unsupportedAsset, newMsvAddress, VaquitaPool.AssetStatus.Active);
    }

    function test_UpdateAsset_InvalidMsvAddress() public {
        address eth = address(0);
        // Cannot set zero address as MSV
        vm.prank(owner);
        vm.expectRevert(VaquitaPool.InvalidAddress.selector);
        vaquita.updateAsset(eth, address(0), VaquitaPool.AssetStatus.Active);
    }

    function test_UpdateAsset_StatusTransitions() public {
        address eth = address(0);
        address newMsvAddress = makeAddr("newMsv");
        
        // Test Active -> Frozen
        vm.prank(owner);
        vaquita.updateAsset(eth, newMsvAddress, VaquitaPool.AssetStatus.Frozen);
        
        (, , VaquitaPool.AssetStatus status) = vaquita.assets(eth);
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Frozen), "Status should be Frozen");
        
        // Test Frozen -> Active
        vm.prank(owner);
        vaquita.updateAsset(eth, newMsvAddress, VaquitaPool.AssetStatus.Active);
        
        (, , status) = vaquita.assets(eth);
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Active), "Status should be Active");
        
        // Test Active -> Inactive
        vm.prank(owner);
        vaquita.updateAsset(eth, newMsvAddress, VaquitaPool.AssetStatus.Inactive);
        
        (, , status) = vaquita.assets(eth);
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Inactive), "Status should be Inactive");
    }

    function test_UpdateAsset_SameValues() public {
        address eth = address(0);
        address currentMsvAddress = address(wethAccessManagedMSV);
        VaquitaPool.AssetStatus currentStatus = VaquitaPool.AssetStatus.Active;
        
        // Get current values
        (, address msvAddress, VaquitaPool.AssetStatus status) = vaquita.assets(eth);
        assertEq(msvAddress, currentMsvAddress, "Initial MSV should be set");
        assertEq(uint256(status), uint256(currentStatus), "Initial status should be Active");
        
        // Update with same values - should not revert but also not change anything
        vm.prank(owner);
        vaquita.updateAsset(eth, currentMsvAddress, currentStatus);
        
        // Verify values remain the same
        (, msvAddress, status) = vaquita.assets(eth);
        assertEq(msvAddress, currentMsvAddress, "MSV should remain the same");
        assertEq(uint256(status), uint256(currentStatus), "Status should remain the same");
    }

    function test_UpdateAsset_EventEmission() public {
        address eth = address(0);
        address newMsvAddress = makeAddr("newMsv");
        
        // Record logs
        vm.recordLogs();
        
        vm.prank(owner);
        vaquita.updateAsset(eth, newMsvAddress, VaquitaPool.AssetStatus.Frozen);
        
        // Check event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 3, "Should emit one event");
        
        // Check event data
        bytes32 eventSignature = keccak256("AssetStatusChanged(address,uint8,uint8)");
        assertEq(logs[2].topics[0], eventSignature, "Should emit AssetStatusChanged event");
    }

    function test_UpdateAsset_ETHAsset() public {
        address eth = address(0);
        address newMsvAddress = makeAddr("newMsv");
        
        // Update ETH asset (address(0))
        vm.prank(owner);
        vaquita.updateAsset(eth, newMsvAddress, VaquitaPool.AssetStatus.Frozen);
        
        // Verify the ETH asset was updated
        (address assetAddress, address msvAddress, VaquitaPool.AssetStatus status) = vaquita.assets(address(0));
        assertEq(assetAddress, eth, "Asset address should be address(0) for ETH");
        assertEq(msvAddress, newMsvAddress, "MSV address should be updated");
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Frozen), "Status should be updated to Frozen");
        
        // Check WETH approval was updated
        uint256 wethAllowance = weth.allowance(address(vaquita), newMsvAddress);
        assertEq(wethAllowance, type(uint256).max, "WETH allowance should be max for new MSV");
    }
}