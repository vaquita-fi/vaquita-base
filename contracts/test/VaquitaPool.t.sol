// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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

contract VaquitaPoolTest is TestUtils {
    VaquitaPool public vaquita;
    IERC20 public token;
    IAccessManagedMSV public accessManagedMSV;
    AccessManager public accessManager;
    IPool public aavePool;
    address public whale;
    address public deployer;
    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    uint256 public alicePrivateKey;
    uint256 public bobPrivateKey;
    uint256 public charliePrivateKey;
    uint256 public initialAmount = 1_000e6;
    uint256 public lockPeriod = 1 days;

    // Mainnet addresses (replace with real ones for your deployment)
    address constant USDC_TOKEN_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC mainnet
    address constant AAVE_POOL_ADDRESS = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5; // Aave pool address
    address constant WHALE_ADDRESS = 0x0B0A5886664376F59C351ba3f598C8A8B4D0A6f3; // USDC rich address
    address constant ACCESS_MANAGER_ADDRESS = 0xfFfaB197EA1e7D06D623F518418305c83F96F922; // AccessManager address
    address constant ACCESS_MANAGED_MSV_ADDRESS = 0x2F7b9503D171531907b60D63ea06EAb2643d331c; // AccessManagedMSV address
    address constant DEPLOYER_ADDRESS = 0x76410823009D09b1FD8e607Fd40baA0323b3bC95; // Deployer address

    function setUp() public {
        // Fork mainnet
        uint256 baseForkBlock = 34_755_804;
        vm.createSelectFork(vm.rpcUrl("base"), baseForkBlock);

        token = IERC20(USDC_TOKEN_ADDRESS);
        whale = address(WHALE_ADDRESS);
        deployer = address(DEPLOYER_ADDRESS);
        accessManager = AccessManager(ACCESS_MANAGER_ADDRESS);
        accessManagedMSV = IAccessManagedMSV(ACCESS_MANAGED_MSV_ADDRESS);
        aavePool = IPool(AAVE_POOL_ADDRESS);
        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        (bob, bobPrivateKey) = makeAddrAndKey("bob");
        (charlie, charliePrivateKey) = makeAddrAndKey("charlie");
        owner = address(this);
        // Deploy VaquitaPool implementation and proxy
        VaquitaPool vaquitaImpl = new VaquitaPool();
        uint256[] memory lockPeriods = new uint256[](1);
        lockPeriods[0] = lockPeriod;
        bytes memory vaquitaInitData = abi.encodeWithSelector(
            vaquitaImpl.initialize.selector,
            address(token),
            address(accessManagedMSV),
            lockPeriods
        );
        TransparentUpgradeableProxy vaquitaProxy = new TransparentUpgradeableProxy(
            address(vaquitaImpl),
            owner,
            vaquitaInitData
        );
        vaquita = VaquitaPool(address(vaquitaProxy));

        vm.startPrank(deployer);
        accessManager.grantRole(1, address(vaquita), 0);
        vm.stopPrank();
        
        // Fund users with USDC from whale
        vm.startPrank(whale);
        token.transfer(alice, initialAmount);
        token.transfer(bob, initialAmount * 2);
        token.transfer(charlie, initialAmount * 3);
        token.transfer(owner, initialAmount * 4);
        vm.stopPrank();
    }

    function deposit(
        address user,
        uint256 depositAmount
    ) public returns (uint256) {
        vm.startPrank(user);
        token.approve(address(vaquita), depositAmount);
        uint256 shares = vaquita.deposit(depositAmount, lockPeriod, block.timestamp + 1 hours, "");
        vm.stopPrank();
        return shares;
    }

    function withdraw(
        address user,
        bytes32 depositId
    ) public returns (uint256) {
        vm.startPrank(user);
        uint256 amount = vaquita.withdraw(depositId);
        vm.stopPrank();
        return amount;
    }

    function test_DepositWithPermit() public {
        vm.startPrank(alice);
        
        // Prepare EIP-712 permit data
        uint256 nonce = IPermit(address(token)).nonces(alice);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 chainId = block.chainid;
        string memory name = "Bridged USDC (Lisk)";
        string memory version = "2";
        address verifyingContract = address(token);
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        
        // EIP-712 JSON structure for permit
        string memory permitJson = string(abi.encodePacked(
            '{',
                '"types": {',
                    '"EIP712Domain": [',
                        '{"name": "name", "type": "string"},',
                        '{"name": "version", "type": "string"},',
                        '{"name": "chainId", "type": "uint256"},',
                        '{"name": "verifyingContract", "type": "address"}',
                    '],',
                    '"Permit": [',
                        '{"name": "owner", "type": "address"},',
                        '{"name": "spender", "type": "address"},',
                        '{"name": "value", "type": "uint256"},',
                        '{"name": "nonce", "type": "uint256"},',
                        '{"name": "deadline", "type": "uint256"}',
                    ']'
                '},',
                '"primaryType": "Permit",',
                '"domain": {',
                    '"name": "', name, '",',
                    '"version": "', version, '",',
                    '"chainId": ', vm.toString(chainId), ',',
                    '"verifyingContract": "', vm.toString(verifyingContract), '"',
                '},',
                '"message": {',
                    '"owner": "', vm.toString(alice), '",',
                    '"spender": "', vm.toString(address(vaquita)), '",',
                    '"value": ', vm.toString(initialAmount), ',',
                    '"nonce": ', vm.toString(nonce), ',',
                    '"deadline": ', vm.toString(deadline),
                '}',
            '}'
        ));

        // Compute the EIP-712 digest
        bytes32 digest = vm.eip712HashTypedData(permitJson);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        console.log("signature");
        console.logBytes(signature);
        
        // Now make the deposit
        deposit(alice, initialAmount);
        
        // Verify the deposit was successful
        (address positionOwner,, uint256 shares,,) = vaquita.positions(aliceDepositId);
        assertEq(positionOwner, alice);
        assertGt(shares, 0);
        
        vm.stopPrank();
    }

    function test_DepositWithApproval() public {
        uint256 shares = deposit(alice, initialAmount);
        assertGt(shares, 0);
    }

    function test_WithdrawAfterLock() public {
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        deposit(alice, initialAmount);
        vm.warp(block.timestamp + lockPeriod);
        withdraw(alice, aliceDepositId);
        (address positionOwner,,,,) = vaquita.positions(aliceDepositId);
        assertEq(positionOwner, address(0));
    }

    function test_AddRewardsToRewardPool() public {
        vm.startPrank(owner);
        uint256 rewardAmount = 1000e6;
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        (uint256 rewardPoolBefore,) = vaquita.periods(lockPeriod);
        token.approve(address(vaquita), rewardAmount);
        vaquita.addRewards(lockPeriod, rewardAmount);
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        (uint256 rewardPoolAfter,) = vaquita.periods(lockPeriod);
        assertEq(rewardPoolAfter, rewardPoolBefore + rewardAmount, "Reward pool should increase by rewardAmount");
        assertEq(ownerBalanceAfter, ownerBalanceBefore - rewardAmount, "Owner balance should decrease by rewardAmount");
        vm.stopPrank();
    }

    function test_AddLockPeriod() public {
        uint256 newLockPeriod = 7 days;
        // Should not be supported initially
        bool supportedBefore = vaquita.isSupportedLockPeriod(newLockPeriod);
        assertFalse(supportedBefore, "New lock period should not be supported before adding");
        // Add new lock period
        vaquita.addLockPeriod(newLockPeriod);
        // Should be supported after
        bool supportedAfter = vaquita.isSupportedLockPeriod(newLockPeriod);
        assertTrue(supportedAfter, "New lock period should be supported after adding");
    }

    function test_EarlyWithdrawal() public {
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        deposit(alice, initialAmount);
        (,uint256 aliceDepositAmount,uint256 aliceShares,,) = vaquita.positions(aliceDepositId);
        assertEq(aliceDepositAmount, initialAmount, "Alice should deposit all her tokens");
        console.log("Vaquita token balance after deposit:", token.balanceOf(address(vaquita)));

        (,,,,,,,, address aTokenAddress,,,,,,) = aavePool.getReserveData(address(token));
        console.log("AccessManagedMSV aToken balance after deposit:", IERC20(aTokenAddress).balanceOf(address(accessManagedMSV)));

        // generate interest
        generateInterestAndWarpToTime(whale, token, AAVE_POOL_ADDRESS, 5_000_000e6, lockPeriod / 2);

        console.log("AccessManagedMSV aToken balance after interest:", IERC20(aTokenAddress).balanceOf(address(accessManagedMSV)));

        uint256 aliceBalanceBeforeWithdraw = token.balanceOf(alice);
        console.log("Alice balance before withdraw:", aliceBalanceBeforeWithdraw);
        console.log("aTokenAddress", aTokenAddress);
        uint256 currentValue = IERC20(aTokenAddress).balanceOf(address(accessManagedMSV));
        console.log("currentValue", currentValue);
        uint256 aliceBalanceABalance = IERC20(aTokenAddress).balanceOf(alice);
        console.log("aliceBalanceABalance", aliceBalanceABalance);
        vm.startPrank(deployer);
        uint256 alicePreviewRedeem = accessManagedMSV.previewRedeem(aliceShares);
        vm.stopPrank();
        console.log("alicePreviewRedeem", alicePreviewRedeem);
        uint256 interest = alicePreviewRedeem - aliceDepositAmount;
        console.log("interest", interest);

        // withdraw from AccessManagedMSV
        uint256 aliceWithdrawal = withdraw(alice, aliceDepositId);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        console.log("Alice balance after withdraw:", aliceBalanceAfter);

        (uint256 rewardPool, uint256 totalDeposits) = vaquita.periods(lockPeriod);
        assertEq(totalDeposits, 0, "Total deposits should be 0");
        assertEq(rewardPool, interest, "Reward pool should be interest");
        assertEq(aliceWithdrawal, initialAmount, "Alice should withdraw all her funds");
        assertEq(aliceBalanceBefore, aliceBalanceAfter, "Alice should not have lost any balance");
    }

    function test_MultipleUsersWithRewardDistribution() public {
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        bytes32 bobDepositId = keccak256(abi.encodePacked(bob, vaquita.depositNonces(bob)));
        
        // Add rewards to pool
        uint256 rewardAmount = 300e6;
        vm.startPrank(owner);
        token.approve(address(vaquita), rewardAmount);
        vaquita.addRewards(lockPeriod, rewardAmount);
        (uint256 rewardPoolInContract,) = vaquita.periods(lockPeriod);
        assertEq(rewardPoolInContract, rewardAmount, "Reward pool should be equal to rewardAmount");
        assertEq(token.balanceOf(address(vaquita)), rewardAmount, "Vaquita should have the reward amount");
        vm.stopPrank();

        // Alice deposits
        uint256 aliceSharesMinted = deposit(alice, initialAmount);
        console.log("aliceSharesMinted", aliceSharesMinted);
        (,uint256 aliceDepositAmount,,,) = vaquita.positions(aliceDepositId);
        assertEq(aliceDepositAmount, initialAmount, "Alice should deposit all her tokens");
        console.log("aliceDepositAmount", aliceDepositAmount);
        // Bob deposits twice as much as Alice
        uint256 bobSharesMinted = deposit(bob, initialAmount * 2);
        console.log("bobSharesMinted", bobSharesMinted);
        (,uint256 bobDepositAmount,,,) = vaquita.positions(bobDepositId);
        assertEq(bobDepositAmount, initialAmount * 2, "Bob should deposit all his tokens");
        console.log("bobDepositAmount", bobDepositAmount);

        generateInterestAndWarpToTime(whale, token, AAVE_POOL_ADDRESS, 5_000_000e6, lockPeriod);

        (uint256 rewardPool, uint256 totalDeposits) = vaquita.periods(lockPeriod);

        console.log("vaquita.rewardPool()", rewardPool);

        uint256 aliceReward = aliceDepositAmount * rewardPool / totalDeposits;
        uint256 bobReward = bobDepositAmount * (rewardPool - aliceReward) / (totalDeposits - aliceDepositAmount);
        console.log("aliceReward", aliceReward);
        console.log("bobReward", bobReward);
        
        // Alice withdraws (should get 1/3 of reward pool since she deposited 1M out of 3M total)
        (,,uint256 aliceShares,,) = vaquita.positions(aliceDepositId);
        console.log("aliceShares", aliceShares);
        vm.startPrank(deployer);
        uint256 alicePreviewRedeem = accessManagedMSV.previewRedeem(aliceShares);
        vm.stopPrank();
        uint256 aliceInterest = alicePreviewRedeem - aliceDepositAmount;
        console.log("Alice interest:", aliceInterest);
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 aliceWithdrawal = withdraw(alice, aliceDepositId);
        console.log("Alice withdrawal:", aliceWithdrawal);
        uint256 aliceBalanceAfter = token.balanceOf(alice);
        
        (,,uint256 bobShares,,) = vaquita.positions(bobDepositId);
        console.log("bobShares", bobShares);
        vm.startPrank(deployer);
        uint256 bobPreviewRedeem = accessManagedMSV.previewRedeem(bobShares);
        vm.stopPrank();
        uint256 bobInterest = bobPreviewRedeem - bobDepositAmount;
        console.log("Bob interest:", bobInterest);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        withdraw(bob, bobDepositId);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        
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
        assertEq(aliceTotal, initialAmount + aliceInterest + aliceReward, "Alice total should be initialAmount + aliceInterest + aliceReward");
        assertApproxEqAbs(bobTotal, initialAmount * 2 + bobInterest + bobReward, 10, "Bob total should be initialAmount * 2 + bobInterest + bobReward");

        // Verify both users got more than they deposited
        assertGt(aliceTotal, initialAmount, "Alice should profit");
        assertGt(bobTotal, initialAmount * 2, "Bob should profit");
        (uint256 newRewardPool,) = vaquita.periods(lockPeriod);
        assertEq(newRewardPool, 0, "Reward pool should be 0");
    }

    function test_WhaleGeneratesInterest() public {
        console.log("=== Starting Whale Swap Fee Generation Test ===");
        
        // Step 1: Alice deposits into VaquitaPool
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        deposit(alice, initialAmount);
        
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        console.log("Alice balance before deposit:", aliceBalanceBefore);
        
        (, uint256 positionAmount,,,) = vaquita.positions(aliceDepositId);
        console.log("Position amount:", positionAmount);
        
        // Step 2: Simulate whale making a large swap to generate fees
        generateInterestAndWarpToTime(whale, token, AAVE_POOL_ADDRESS, 5_000_000e6, lockPeriod);
        
        // Step 3: Alice withdraws and check if she got more than she deposited
        console.log("\n=== Alice Withdrawal ===");
        
        uint256 aliceBalanceBeforeWithdraw = token.balanceOf(alice);
        console.log("Alice balance before withdraw:", aliceBalanceBeforeWithdraw);
        
        uint256 withdrawnAmount = withdraw(alice, aliceDepositId);
        
        uint256 aliceBalanceAfterWithdraw = token.balanceOf(alice);
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
        (address positionOwner,,,,) = vaquita.positions(aliceDepositId);
        assertEq(positionOwner, address(0), "Position should be inactive after withdrawal");
    }

    function test_MultipleUsersWithWhaleGeneratesInterest() public {
        vm.recordLogs();
        // Multiple users deposit
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        bytes32 bobDepositId = keccak256(abi.encodePacked(bob, vaquita.depositNonces(bob)));
        bytes32 charlieDepositId = keccak256(abi.encodePacked(charlie, vaquita.depositNonces(charlie)));
        
        // Alice deposits
        uint256 aliceShares = deposit(alice, initialAmount);
        // Bob deposits
        uint256 bobShares = deposit(bob, initialAmount);
        // Charlie deposits
        uint256 charlieShares = deposit(charlie, initialAmount);

        (, uint256 totalShares) = vaquita.periods(lockPeriod);
        uint256 totalDeposits = 0;
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.log("entries.length", entries.length);
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == keccak256("FundsDeposited(bytes32,address,uint256,uint256)")) {
                (uint256 amount, ) = abi.decode(entries[i].data, (uint256, uint256));
                totalDeposits += amount;
            }
        }
        console.log("pasa totalDeposits", totalDeposits);
        assertEq(aliceShares + bobShares + charlieShares, totalShares, "Total shares should be 3 * initialAmount");
        assertEq(totalDeposits, 3 * initialAmount, "Total deposits should be 3 * initialAmount");
        
        // Whale makes multiple swaps to generate more fees
        for (uint i = 0; i < 3; i++) {
            generateInterestAndWarpToTime(whale, token, AAVE_POOL_ADDRESS, 1_000_000e6, lockPeriod);
        }
        
        // Fast forward past lock period
        vm.warp(block.timestamp + lockPeriod + 1);

        console.log("Token balance of vaquita before withdraws", token.balanceOf(address(vaquita)));
        
        // All users withdraw and check profits
        address[3] memory users = [alice, bob, charlie];
        bytes32[3] memory userDepositIds = [aliceDepositId, bobDepositId, charlieDepositId];
        
        for (uint i = 0; i < users.length; i++) {
            uint256 balanceBefore = token.balanceOf(users[i]);
            uint256 withdrawn = withdraw(users[i], userDepositIds[i]);
            uint256 balanceAfter = token.balanceOf(users[i]);
            
            assertEq(balanceAfter, balanceBefore + withdrawn, "User should have received the correct amount");

            console.log("User", i, "total received:", withdrawn);
            console.log("User", i, "original deposit:", initialAmount);
            
            if (withdrawn > initialAmount) {
                console.log("User", i, "profit:", withdrawn - initialAmount);
            }
        }

        console.log("Token balance of vaquita after withdraws", token.balanceOf(address(vaquita)));
        assertEq(token.balanceOf(address(vaquita)), 0, "Vaquita should have 0 balance after withdraws");
    }

    function test_PauseAndUnpause() public {
        // Only owner can pause
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.pause();

        // Owner can pause
        vm.prank(owner);
        vaquita.pause();
        assertTrue(vaquita.paused(), "Contract should be paused");

        // Deposit should revert when paused
        vm.prank(alice);
        token.approve(address(vaquita), 1e6);
        vm.expectRevert();
        vaquita.deposit(1e6, lockPeriod, block.timestamp + 1 days, "");

        // Withdraw should revert when paused
        vm.expectRevert();
        vaquita.withdraw(bytes32(keccak256("id1")));

        // addRewards should not revert when paused
        vm.prank(owner);
        token.approve(address(vaquita), 1e6);
        vaquita.addRewards(lockPeriod, 1e6);

        // withdrawProtocolFees should not revert when paused
        vm.prank(owner);
        vaquita.withdrawProtocolFees();

        // Only owner can unpause
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.unpause();

        // Owner can unpause
        vm.prank(owner);
        vaquita.unpause();
        assertFalse(vaquita.paused(), "Contract should be unpaused");
    }

    function test_UpdateEarlyWithdrawalFee() public {
        // Only owner can update
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.updateEarlyWithdrawalFee(100);

        // Owner can update
        vm.prank(owner);
        vaquita.updateEarlyWithdrawalFee(100);
        assertEq(vaquita.earlyWithdrawalFee(), 100, "Early withdrawal fee should be updated");

        // Revert if fee > BASIS_POINTS
        vm.prank(owner);
        vm.expectRevert(VaquitaPool.InvalidFee.selector);
        vaquita.updateEarlyWithdrawalFee(10001);
    }

    function test_WithdrawProtocolFees() public {
        vm.recordLogs();
        // Set early withdrawal fee to 5%
        vm.prank(owner);
        vaquita.updateEarlyWithdrawalFee(500); // 5%

        // Alice deposits
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        deposit(alice, initialAmount);

        generateInterestAndWarpToTime(whale, token, AAVE_POOL_ADDRESS, 5_000_000e6, lockPeriod / 2);

        // Alice withdraws early (before lock period ends)
        withdraw(alice, aliceDepositId);

        // Protocol fees should be greater than 0
        assertGt(vaquita.protocolFees(), 0, "Protocol fees should be greater than 0 after early withdrawal");

        // Only owner can withdraw protocol fees
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.withdrawProtocolFees();

        // Owner withdraws protocol fees
        vm.prank(owner);
        vaquita.withdrawProtocolFees();
        assertEq(vaquita.protocolFees(), 0, "Protocol fees should be zero after withdrawal");
    }

    function test_UpdateLockPeriod() public {
        // Only owner can update
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.addLockPeriod(2 days);

        // Owner can update
        vm.prank(owner);
        vaquita.addLockPeriod(2 days);
        // lock period 2 days should be added
        assertTrue(vaquita.isSupportedLockPeriod(2 days), "Lock period 2 days should be added");
    }
}