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

contract VaquitaPoolUsdcTest is TestUtils {
    VaquitaPool public vaquita;
    IERC20 public usdc;
    IERC20 public usdt;
    IWETH public weth;
    IAccessManagedMSV public usdcAccessManagedMSV;
    IAccessManagedMSV public usdtAccessManagedMSV;
    IAccessManagedMSV public wethAccessManagedMSV;
    AccessManager public usdcAccessManager;
    AccessManager public usdtAccessManager;
    AccessManager public wethAccessManager;
    IPool public aavePool;
    address public usdcWhale;
    address public usdtWhale;
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

    // Base Sepolia addresses
    address constant USDC_TOKEN_ADDRESS = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC Base Sepolia
    address constant USDT_TOKEN_ADDRESS = 0x0a215D8ba66387DCA84B284D18c3B4ec3de6E54a; // USDT Base Sepolia
    address constant WETH_TOKEN_ADDRESS = 0x4200000000000000000000000000000000000006; // WETH Base Sepolia
    address constant USDC_AAVE_POOL_ADDRESS = 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b; // Aave pool address for USDC
    address constant USDT_AAVE_POOL_ADDRESS = 0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27; // Aave pool address for USDT
    address constant WETH_AAVE_POOL_ADDRESS = 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b; // Aave pool address for WETH
    address constant USDC_WHALE_ADDRESS = 0xFaEc9cDC3Ef75713b48f46057B98BA04885e3391; // USDC rich address
    address constant USDT_WHALE_ADDRESS = 0xcE3CAae5Ed17A7AafCEEbc897DE843fA6CC0c018; // USDT rich address
    address constant WETH_WHALE_ADDRESS = 0x598eC92B1d631b6cA5e8E4aB2883D94bbf0FCb8d; // WETH rich address
    address constant USDC_ACCESS_MANAGER_ADDRESS = 0x39833372eaF093285abc571860B6317051Ad58fd; // AccessManager address
    address constant USDC_ACCESS_MANAGED_MSV_ADDRESS = 0xEaC8740c493cD8Cb22E22e79b1a7Bb055Bc9Ef4e; // AccessManagedMSV address
    address constant USDT_ACCESS_MANAGER_ADDRESS = 0xBBcf838B264570af93B1ABB004879Cf7eE915161; // AccessManager address
    address constant USDT_ACCESS_MANAGED_MSV_ADDRESS = 0x0C3423B77334F8703f8A5DDe8F2E1C01d08C39D6; // AccessManagedMSV address
    address constant WETH_ACCESS_MANAGER_ADDRESS = 0xCc020c689BC7a485084d335335bE0c4BE520c3E4; // AccessManager address
    address constant WETH_ACCESS_MANAGED_MSV_ADDRESS = 0x19B4a4A5766a07c533b7E50b2A387b7c9CF91088; // AccessManagedMSV address
    
    address constant DEPLOYER_ADDRESS = 0x76410823009D09b1FD8e607Fd40baA0323b3bC95; // Deployer address

    function setUp() public {
        // Fork base sepolia
        uint256 baseSepoliaForkBlock = 32_214_235;
        vm.createSelectFork(vm.rpcUrl("base-sepolia"), baseSepoliaForkBlock);

        usdc = IERC20(USDC_TOKEN_ADDRESS);
        usdt = IERC20(USDT_TOKEN_ADDRESS);
        weth = IWETH(WETH_TOKEN_ADDRESS);
        usdcWhale = address(USDC_WHALE_ADDRESS);
        usdtWhale = address(USDT_WHALE_ADDRESS);
        deployer = address(DEPLOYER_ADDRESS);
        usdcAccessManager = AccessManager(USDC_ACCESS_MANAGER_ADDRESS);
        usdcAccessManagedMSV = IAccessManagedMSV(USDC_ACCESS_MANAGED_MSV_ADDRESS);
        usdtAccessManager = AccessManager(USDT_ACCESS_MANAGER_ADDRESS);
        usdtAccessManagedMSV = IAccessManagedMSV(USDT_ACCESS_MANAGED_MSV_ADDRESS);
        wethAccessManager = AccessManager(WETH_ACCESS_MANAGER_ADDRESS);
        wethAccessManagedMSV = IAccessManagedMSV(WETH_ACCESS_MANAGED_MSV_ADDRESS);
        aavePool = IPool(USDC_AAVE_POOL_ADDRESS);
        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        (bob, bobPrivateKey) = makeAddrAndKey("bob");
        (charlie, charliePrivateKey) = makeAddrAndKey("charlie");
        owner = address(this);
        // Deploy VaquitaPool implementation and proxy
        VaquitaPool vaquitaImpl = new VaquitaPool();
        // address[] memory assets = new address[](1);
        // assets[0] = address(usdc);
        address[] memory assets = new address[](6);
        assets[0] = address(usdc);
        assets[1] = address(usdc);
        assets[2] = address(usdt);
        assets[3] = address(usdt);
        assets[4] = address(0);
        assets[5] = address(0);
        address[] memory msvAddresses = new address[](6);
        msvAddresses[0] = address(usdcAccessManagedMSV);
        msvAddresses[1] = address(usdcAccessManagedMSV);
        msvAddresses[2] = address(usdtAccessManagedMSV);
        msvAddresses[3] = address(usdtAccessManagedMSV);
        msvAddresses[4] = address(wethAccessManagedMSV);
        msvAddresses[5] = address(wethAccessManagedMSV);
        uint256[] memory lockPeriods = new uint256[](6);
        lockPeriods[0] = lockPeriod;
        lockPeriods[1] = 1 weeks;
        lockPeriods[2] = lockPeriod;
        lockPeriods[3] = 1 weeks;
        lockPeriods[4] = lockPeriod;
        lockPeriods[5] = 1 weeks;
        bytes memory vaquitaInitData = abi.encodeWithSelector(
            vaquitaImpl.initialize.selector,
            assets,
            msvAddresses,
            lockPeriods,
            address(weth),
            address(owner)
        );
        TransparentUpgradeableProxy vaquitaProxy = new TransparentUpgradeableProxy(
            address(vaquitaImpl),
            owner,
            vaquitaInitData
        );
        vaquita = VaquitaPool(payable(address(vaquitaProxy)));

        vm.startPrank(deployer);
        usdcAccessManager.grantRole(1, address(vaquita), 0);
        usdtAccessManager.grantRole(1, address(vaquita), 0);
        wethAccessManager.grantRole(1, address(vaquita), 0);
        vm.stopPrank();
        
        // Fund users with USDC from whale
        vm.startPrank(usdcWhale);
        usdc.transfer(alice, initialAmount);
        usdc.transfer(bob, initialAmount * 2);
        usdc.transfer(charlie, initialAmount * 3);
        usdc.transfer(owner, initialAmount * 4);
        vm.stopPrank();

        vm.startPrank(usdtWhale);
        usdt.transfer(alice, initialAmount);
        usdt.transfer(bob, initialAmount * 2);
        usdt.transfer(charlie, initialAmount * 3);
        usdt.transfer(owner, initialAmount * 4);
        vm.stopPrank();
        
        // Fund users with ETH for ETH deposits
        vm.deal(alice, 10 ether);
        vm.deal(bob, 20 ether);
        vm.deal(charlie, 30 ether);
        vm.deal(owner, 40 ether);
    }

    function deposit(
        address asset,
        address user,
        uint256 depositAmount
    ) public returns (uint256) {
        vm.startPrank(user);
        IERC20(asset).approve(address(vaquita), depositAmount);
        uint256 shares = vaquita.deposit(asset, depositAmount, lockPeriod, block.timestamp + 1 hours, "");
        vm.stopPrank();
        return shares;
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
        uint256 nonce = IPermit(address(usdc)).nonces(alice);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 chainId = block.chainid;
        string memory name = "USDC";
        string memory version = "2";
        address verifyingContract = address(usdc);
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
        // deposit(address(usdc), alice, initialAmount);
        vaquita.deposit(address(usdc), initialAmount, lockPeriod, block.timestamp + 1 hours, signature);
        
        // Verify the deposit was successful
        (address positionOwner,,, uint256 shares,,) = vaquita.positions(aliceDepositId);
        assertEq(positionOwner, alice);
        assertGt(shares, 0);
        
        vm.stopPrank();
    }

    function test_DepositWithApproval() public {
        uint256 shares = deposit(address(usdc), alice, initialAmount);
        assertGt(shares, 0);
    }

    function test_DepositMultipleAssets() public {
        deposit(address(usdc), alice, initialAmount);
        deposit(address(usdt), alice, initialAmount);
        depositETH(alice, 1 ether);
    }

    function test_WithdrawAfterLock() public {
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        deposit(address(usdc), alice, initialAmount);
        vm.warp(block.timestamp + lockPeriod);
        withdraw(alice, aliceDepositId);
        (address positionOwner,,,,,) = vaquita.positions(aliceDepositId);
        assertEq(positionOwner, address(0));
    }

    function test_AddRewardsToRewardPool() public {
        vm.startPrank(owner);
        uint256 rewardAmount = 1000e6;
        uint256 ownerBalanceBefore = usdc.balanceOf(owner);
        (uint256 rewardPoolBefore,,) = vaquita.periods(lockPeriod, address(usdc));
        usdc.approve(address(vaquita), rewardAmount);
        vaquita.addRewards(lockPeriod, address(usdc), rewardAmount);
        uint256 ownerBalanceAfter = usdc.balanceOf(owner);
        (uint256 rewardPoolAfter,,) = vaquita.periods(lockPeriod, address(usdc));
        assertEq(rewardPoolAfter, rewardPoolBefore + rewardAmount, "Reward pool should increase by rewardAmount");
        assertEq(ownerBalanceAfter, ownerBalanceBefore - rewardAmount, "Owner balance should decrease by rewardAmount");
        vm.stopPrank();
    }

    function test_AddLockPeriod() public {
        uint256 newLockPeriod = 30 days;
        // Should not be supported initially
        bool supportedBefore = vaquita.isSupportedLockPeriod(newLockPeriod, address(usdc));
        assertFalse(supportedBefore, "New lock period should not be supported before adding");
        // Add new lock period
        vaquita.addLockPeriod(newLockPeriod, address(usdc));
        // Should be supported after
        bool supportedAfter = vaquita.isSupportedLockPeriod(newLockPeriod, address(usdc));
        assertTrue(supportedAfter, "New lock period should be supported after adding");
    }

    function test_PerformanceFee_EarlyWithdrawal() public {
        vaquita.updatePerformanceFee(1000);
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        deposit(address(usdc), alice, initialAmount);
        (,,uint256 aliceDepositAmount,uint256 aliceShares,,) = vaquita.positions(aliceDepositId);
        assertEq(aliceDepositAmount, initialAmount, "Alice should deposit all her tokens");
        console.log("Vaquita token balance after deposit:", usdc.balanceOf(address(vaquita)));

        (,,,,,,,, address aTokenAddress,,,,,,) = aavePool.getReserveData(address(usdc));
        console.log("AccessManagedMSV aToken balance after deposit:", IERC20(aTokenAddress).balanceOf(address(usdcAccessManagedMSV)));

        // generate interest
        generateInterestAndWarpToTime(usdcWhale, usdc, USDC_AAVE_POOL_ADDRESS, 5_000_000e6, lockPeriod / 2);

        console.log("AccessManagedMSV aToken balance after interest:", IERC20(aTokenAddress).balanceOf(address(usdcAccessManagedMSV)));

        uint256 aliceBalanceBeforeWithdraw = usdc.balanceOf(alice);
        console.log("Alice balance before withdraw:", aliceBalanceBeforeWithdraw);
        console.log("aTokenAddress", aTokenAddress);
        uint256 currentValue = IERC20(aTokenAddress).balanceOf(address(usdcAccessManagedMSV));
        console.log("currentValue", currentValue);
        uint256 aliceBalanceABalance = IERC20(aTokenAddress).balanceOf(alice);
        console.log("aliceBalanceABalance", aliceBalanceABalance);
        vm.startPrank(deployer);
        uint256 alicePreviewRedeem = usdcAccessManagedMSV.previewRedeem(aliceShares);
        console.log("alicePreviewRedeem", alicePreviewRedeem);
        vm.stopPrank();
        console.log("alicePreviewRedeem", alicePreviewRedeem);
        uint256 interest = alicePreviewRedeem - aliceDepositAmount;
        console.log("interest", interest);

        // withdraw from AccessManagedMSV
        uint256 aliceWithdrawal = withdraw(alice, aliceDepositId);

        uint256 aliceBalanceAfter = usdc.balanceOf(alice);
        console.log("Alice balance after withdraw:", aliceBalanceAfter);

        (uint256 rewardPool, uint256 totalDeposits,) = vaquita.periods(lockPeriod, address(usdc));
        uint256 performanceFee = interest * 1000 / 10000;
        console.log("performanceFee", performanceFee);
        assertEq(totalDeposits, 0, "Total deposits should be 0");
        assertEq(rewardPool, interest - performanceFee, "Reward pool should be interest");
        assertEq(vaquita.protocolFees(), performanceFee, "Protocol fees should be performance fee");
        assertEq(aliceWithdrawal, initialAmount, "Alice should withdraw all her funds");
        assertEq(aliceBalanceBefore, aliceBalanceAfter, "Alice should not have lost any balance");
    }

    function test_PerformanceFee_LateWithdrawal() public {
        vaquita.updatePerformanceFee(1000);
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        deposit(address(usdc), alice, initialAmount);
        (,,uint256 aliceDepositAmount,uint256 aliceShares,,) = vaquita.positions(aliceDepositId);
        assertEq(aliceDepositAmount, initialAmount, "Alice should deposit all her tokens");
        console.log("Vaquita token balance after deposit:", usdc.balanceOf(address(vaquita)));

        (,,,,,,,, address aTokenAddress,,,,,,) = aavePool.getReserveData(address(usdc));
        console.log("AccessManagedMSV aToken balance after deposit:", IERC20(aTokenAddress).balanceOf(address(usdcAccessManagedMSV)));

        // generate interest
        generateInterestAndWarpToTime(usdcWhale, usdc, USDC_AAVE_POOL_ADDRESS, 5_000_000e6, lockPeriod);

        console.log("AccessManagedMSV aToken balance after interest:", IERC20(aTokenAddress).balanceOf(address(usdcAccessManagedMSV)));

        uint256 aliceBalanceBeforeWithdraw = usdc.balanceOf(alice);
        console.log("Alice balance before withdraw:", aliceBalanceBeforeWithdraw);
        console.log("aTokenAddress", aTokenAddress);
        uint256 currentValue = IERC20(aTokenAddress).balanceOf(address(usdcAccessManagedMSV));
        console.log("currentValue", currentValue);
        uint256 aliceBalanceABalance = IERC20(aTokenAddress).balanceOf(alice);
        console.log("aliceBalanceABalance", aliceBalanceABalance);
        vm.startPrank(deployer);
        uint256 alicePreviewRedeem = usdcAccessManagedMSV.previewRedeem(aliceShares);
        console.log("alicePreviewRedeem", alicePreviewRedeem);
        vm.stopPrank();
        console.log("alicePreviewRedeem", alicePreviewRedeem);
        uint256 interest = alicePreviewRedeem - aliceDepositAmount;
        console.log("interest", interest);

        // withdraw from AccessManagedMSV
        uint256 aliceWithdrawal = withdraw(alice, aliceDepositId);

        uint256 aliceBalanceAfter = usdc.balanceOf(alice);
        console.log("Alice balance after withdraw:", aliceBalanceAfter);

        (uint256 rewardPool, uint256 totalDeposits,) = vaquita.periods(lockPeriod, address(usdc));
        uint256 performanceFee = interest * 1000 / 10000;
        console.log("performanceFee", performanceFee);
        assertEq(totalDeposits, 0, "Total deposits should be 0");
        assertEq(rewardPool, 0, "Reward pool should be interest");
        assertEq(vaquita.protocolFees(), performanceFee, "Protocol fees should be performance fee");
        assertEq(aliceWithdrawal, initialAmount + interest - performanceFee, "Alice should withdraw all her funds");
    }

    function test_MultipleUsersWithRewardDistribution() public {
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        bytes32 bobDepositId = keccak256(abi.encodePacked(bob, vaquita.depositNonces(bob)));
        
        // Add rewards to pool
        uint256 rewardAmount = 300e6;
        vm.startPrank(owner);
        usdc.approve(address(vaquita), rewardAmount);
        vaquita.addRewards(lockPeriod, address(usdc), rewardAmount);
        (uint256 rewardPoolInContract,,) = vaquita.periods(lockPeriod, address(usdc));
        assertEq(rewardPoolInContract, rewardAmount, "Reward pool should be equal to rewardAmount");
        assertEq(usdc.balanceOf(address(vaquita)), rewardAmount, "Vaquita should have the reward amount");
        vm.stopPrank();

        // Alice deposits
        uint256 aliceSharesMinted = deposit(address(usdc), alice, initialAmount);
        console.log("aliceSharesMinted", aliceSharesMinted);
        (,,uint256 aliceDepositAmount,,,) = vaquita.positions(aliceDepositId);
        assertEq(aliceDepositAmount, initialAmount, "Alice should deposit all her tokens");
        console.log("aliceDepositAmount", aliceDepositAmount);
        vm.startPrank(deployer);
        uint256 aliceInitialAmountInAssets = usdcAccessManagedMSV.convertToAssets(aliceSharesMinted);
        console.log("aliceInitialAmountInAssets", aliceInitialAmountInAssets);
        vm.stopPrank();
        // Bob deposits twice as much as Alice
        uint256 bobSharesMinted = deposit(address(usdc), bob, initialAmount * 2);
        console.log("bobSharesMinted", bobSharesMinted);
        (,,uint256 bobDepositAmount,,,) = vaquita.positions(bobDepositId);
        assertEq(bobDepositAmount, initialAmount * 2, "Bob should deposit all his tokens");
        console.log("bobDepositAmount", bobDepositAmount);
        vm.startPrank(deployer);
        uint256 bobInitialAmountInAssets = usdcAccessManagedMSV.convertToAssets(bobSharesMinted);
        console.log("bobInitialAmountInAssets", bobInitialAmountInAssets);
        vm.stopPrank();

        generateInterestAndWarpToTime(usdcWhale, usdc, USDC_AAVE_POOL_ADDRESS, 5_000_000e6, lockPeriod);

        (uint256 rewardPool, uint256 totalDeposits,) = vaquita.periods(lockPeriod, address(usdc));

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
        uint256 alicePreviewRedeem = usdcAccessManagedMSV.previewRedeem(aliceShares);
        console.log("alicePreviewRedeem", alicePreviewRedeem);
        vm.stopPrank();
        uint256 aliceInterest = alicePreviewRedeem - aliceDepositAmount;
        console.log("Alice interest:", aliceInterest);
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        vm.startPrank(deployer);
        uint256 aliceFinalSharesToAssets = usdcAccessManagedMSV.convertToAssets(aliceShares);
        console.log("aliceFinalSharesToAssets", aliceFinalSharesToAssets);
        vm.stopPrank();
        uint256 aliceWithdrawal = withdraw(alice, aliceDepositId);
        console.log("Alice withdrawal:", aliceWithdrawal);
        // assertEq(aliceWithdrawal, aliceFinalSharesToAssets + aliceReward, "Alice withdrawal should be equal to aliceFinalSharesToAssets + aliceInterest");
        uint256 aliceBalanceAfter = usdc.balanceOf(alice);
        
        (,,,uint256 bobShares,,) = vaquita.positions(bobDepositId);
        console.log("bobShares", bobShares);
        vm.startPrank(deployer);
        uint256 bobPreviewRedeem = usdcAccessManagedMSV.previewRedeem(bobShares);
        console.log("bobPreviewRedeem", bobPreviewRedeem);
        vm.stopPrank();
        uint256 bobInterest = bobPreviewRedeem - bobDepositAmount;
        console.log("Bob interest:", bobInterest);
        uint256 bobBalanceBefore = usdc.balanceOf(bob);
        vm.startPrank(deployer);
        uint256 bobFinalSharesToAssets = usdcAccessManagedMSV.convertToAssets(bobShares);
        console.log("bobFinalSharesToAssets", bobFinalSharesToAssets);
        vm.stopPrank();
        withdraw(bob, bobDepositId);
        uint256 bobBalanceAfter = usdc.balanceOf(bob);
        
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
        (uint256 newRewardPool,,) = vaquita.periods(lockPeriod, address(usdc));
        assertEq(newRewardPool, 0, "Reward pool should be 0");
    }

    function test_WhaleGeneratesInterest() public {
        console.log("=== Starting Whale Swap Fee Generation Test ===");
        
        // Step 1: Alice deposits into VaquitaPool
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        deposit(address(usdc), alice, initialAmount);
        
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        console.log("Alice balance before deposit:", aliceBalanceBefore);
        
        (,, uint256 positionAmount,,,) = vaquita.positions(aliceDepositId);
        console.log("Position amount:", positionAmount);
        
        // Step 2: Simulate whale making a large swap to generate fees
        generateInterestAndWarpToTime(usdcWhale, usdc, USDC_AAVE_POOL_ADDRESS, 5_000_000e6, lockPeriod);
        
        // Step 3: Alice withdraws and check if she got more than she deposited
        console.log("\n=== Alice Withdrawal ===");
        
        uint256 aliceBalanceBeforeWithdraw = usdc.balanceOf(alice);
        console.log("Alice balance before withdraw:", aliceBalanceBeforeWithdraw);
        
        uint256 withdrawnAmount = withdraw(alice, aliceDepositId);
        
        uint256 aliceBalanceAfterWithdraw = usdc.balanceOf(alice);
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
        // Multiple users deposit
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        bytes32 bobDepositId = keccak256(abi.encodePacked(bob, vaquita.depositNonces(bob)));
        bytes32 charlieDepositId = keccak256(abi.encodePacked(charlie, vaquita.depositNonces(charlie)));
        
        // Alice deposits
        uint256 aliceShares = deposit(address(usdc), alice, initialAmount);
        // Bob deposits
        uint256 bobShares = deposit(address(usdc), bob, initialAmount);
        // Charlie deposits
        uint256 charlieShares = deposit(address(usdc), charlie, initialAmount);

        (,, uint256 totalShares) = vaquita.periods(lockPeriod, address(usdc));
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
            generateInterestAndWarpToTime(usdcWhale, usdc, USDC_AAVE_POOL_ADDRESS, 1_000_000e6, lockPeriod);
        }
        
        // Fast forward past lock period
        vm.warp(block.timestamp + lockPeriod + 1);

        console.log("Token balance of vaquita before withdraws", usdc.balanceOf(address(vaquita)));
        
        // All users withdraw and check profits
        address[3] memory users = [alice, bob, charlie];
        bytes32[3] memory userDepositIds = [aliceDepositId, bobDepositId, charlieDepositId];
        
        for (uint i = 0; i < users.length; i++) {
            uint256 balanceBefore = usdc.balanceOf(users[i]);
            uint256 withdrawn = withdraw(users[i], userDepositIds[i]);
            uint256 balanceAfter = usdc.balanceOf(users[i]);
            
            assertEq(balanceAfter, balanceBefore + withdrawn, "User should have received the correct amount");

            console.log("User", i, "total received:", withdrawn);
            console.log("User", i, "original deposit:", initialAmount);
            
            if (withdrawn > initialAmount) {
                console.log("User", i, "profit:", withdrawn - initialAmount);
            }
        }

        console.log("Token balance of vaquita after withdraws", usdc.balanceOf(address(vaquita)));
        assertEq(usdc.balanceOf(address(vaquita)), 0, "Vaquita should have 0 balance after withdraws");
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
        usdc.approve(address(vaquita), 1e6);
        vm.expectRevert();
        vaquita.deposit(address(usdc), 1e6, lockPeriod, block.timestamp + 1 days, "");

        // Withdraw should revert when paused
        vm.expectRevert();
        vaquita.withdraw(bytes32(keccak256("id1")));

        // addRewards should not revert when paused
        vm.prank(owner);
        usdc.approve(address(vaquita), 1e6);
        vaquita.addRewards(lockPeriod, address(usdc), 1e6);

        // withdrawProtocolFees should not revert when paused
        vm.prank(owner);
        vaquita.withdrawProtocolFees(address(usdc));

        // Only owner can unpause
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.unpause();

        // Owner can unpause
        vm.prank(owner);
        vaquita.unpause();
        assertFalse(vaquita.paused(), "Contract should be unpaused");
    }

    function test_UpdatePerformanceFee() public {
        // Only owner can update
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
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
        // Set performance fee to 5%
        vm.prank(owner);
        vaquita.updatePerformanceFee(500); // 5%

        // Alice deposits
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        deposit(address(usdc), alice, initialAmount);

        generateInterestAndWarpToTime(usdcWhale, usdc, USDC_AAVE_POOL_ADDRESS, 5_000_000e6, lockPeriod / 2);

        // Alice withdraws early (before lock period ends)
        withdraw(alice, aliceDepositId);

        // Protocol fees should be greater than 0
        assertGt(vaquita.protocolFees(), 0, "Protocol fees should be greater than 0 after early withdrawal");

        // Only owner can withdraw protocol fees
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.withdrawProtocolFees(address(usdc));

        // Owner withdraws protocol fees
        vm.prank(owner);
        vaquita.withdrawProtocolFees(address(usdc));
        assertEq(vaquita.protocolFees(), 0, "Protocol fees should be zero after withdrawal");
    }

    function test_UpdateLockPeriod() public {
        // Only owner can update
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.addLockPeriod(2 days, address(usdc));

        // Owner can update
        vm.prank(owner);
        vaquita.addLockPeriod(2 days, address(usdc));
        // lock period 2 days should be added
        assertTrue(vaquita.isSupportedLockPeriod(2 days, address(usdc)), "Lock period 2 days should be added");
    }

    function test_UpdateAsset_Success() public {
        // Create a new MSV contract for testing
        address newMsvAddress = makeAddr("newMsv");
        
        // Test updating MSV address and status
        vm.prank(owner);
        vaquita.updateAsset(address(usdc), newMsvAddress, VaquitaPool.AssetStatus.Frozen);
        
        // Verify the asset was updated
        (address assetAddress, address msvAddress, VaquitaPool.AssetStatus status) = vaquita.assets(address(usdc));
        assertEq(assetAddress, address(usdc), "Asset address should remain the same");
        assertEq(msvAddress, newMsvAddress, "MSV address should be updated");
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Frozen), "Status should be updated to Frozen");
    }

    function test_UpdateAsset_OnlyOwner() public {
        address newMsvAddress = makeAddr("newMsv");
        
        // Non-owner cannot update asset
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vaquita.updateAsset(address(usdc), newMsvAddress, VaquitaPool.AssetStatus.Frozen);
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
        // Cannot set zero address as MSV
        vm.prank(owner);
        vm.expectRevert(VaquitaPool.InvalidAddress.selector);
        vaquita.updateAsset(address(usdc), address(0), VaquitaPool.AssetStatus.Active);
    }

    function test_UpdateAsset_StatusTransitions() public {
        address newMsvAddress = makeAddr("newMsv");
        
        // Test Active -> Frozen
        vm.prank(owner);
        vaquita.updateAsset(address(usdc), newMsvAddress, VaquitaPool.AssetStatus.Frozen);
        
        (, , VaquitaPool.AssetStatus status) = vaquita.assets(address(usdc));
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Frozen), "Status should be Frozen");
        
        // Test Frozen -> Active
        vm.prank(owner);
        vaquita.updateAsset(address(usdc), newMsvAddress, VaquitaPool.AssetStatus.Active);
        
        (, , status) = vaquita.assets(address(usdc));
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Active), "Status should be Active");
        
        // Test Active -> Inactive
        vm.prank(owner);
        vaquita.updateAsset(address(usdc), newMsvAddress, VaquitaPool.AssetStatus.Inactive);
        
        (, , status) = vaquita.assets(address(usdc));
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Inactive), "Status should be Inactive");
    }

    function test_UpdateAsset_SameValues() public {
        address currentMsvAddress = address(usdcAccessManagedMSV);
        VaquitaPool.AssetStatus currentStatus = VaquitaPool.AssetStatus.Active;
        
        // Get current values
        (, address msvAddress, VaquitaPool.AssetStatus status) = vaquita.assets(address(usdc));
        assertEq(msvAddress, currentMsvAddress, "Initial MSV should be set");
        assertEq(uint256(status), uint256(currentStatus), "Initial status should be Active");
        
        // Update with same values - should not revert but also not change anything
        vm.prank(owner);
        vaquita.updateAsset(address(usdc), currentMsvAddress, currentStatus);
        
        // Verify values remain the same
        (, msvAddress, status) = vaquita.assets(address(usdc));
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

    function test_UpdateAsset_ApprovalManagement() public {
        address newMsvAddress = makeAddr("newMsv");
        
        // Check initial approval
        uint256 initialAllowance = usdc.allowance(address(vaquita), address(usdcAccessManagedMSV));
        assertEq(initialAllowance, type(uint256).max, "Initial allowance should be max");
        
        // Update asset with new MSV
        vm.prank(owner);
        vaquita.updateAsset(address(usdc), newMsvAddress, VaquitaPool.AssetStatus.Active);
        
        // Check old approval was revoked
        uint256 oldAllowance = usdc.allowance(address(vaquita), address(usdcAccessManagedMSV));
        assertEq(oldAllowance, 0, "Old MSV allowance should be revoked");
        
        // Check new approval was set
        uint256 newAllowance = usdc.allowance(address(vaquita), newMsvAddress);
        assertEq(newAllowance, type(uint256).max, "New MSV allowance should be max");
    }

    function test_UpdateAsset_ETHAsset() public {
        address newMsvAddress = makeAddr("newMsv");
        
        // Update ETH asset (address(0))
        vm.prank(owner);
        vaquita.updateAsset(address(0), newMsvAddress, VaquitaPool.AssetStatus.Frozen);
        
        // Verify the ETH asset was updated
        (address assetAddress, address msvAddress, VaquitaPool.AssetStatus status) = vaquita.assets(address(0));
        assertEq(assetAddress, address(0), "Asset address should be address(0) for ETH");
        assertEq(msvAddress, newMsvAddress, "MSV address should be updated");
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Frozen), "Status should be updated to Frozen");
        
        // Check WETH approval was updated
        uint256 wethAllowance = weth.allowance(address(vaquita), newMsvAddress);
        assertEq(wethAllowance, type(uint256).max, "WETH allowance should be max for new MSV");
    }
}