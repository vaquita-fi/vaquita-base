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
import {IWeth} from "../src/interfaces/IWeth.sol";

contract VaquitaPoolCbBtcTest is TestUtils {
    VaquitaPool public vaquita;
    IERC20 public cbBTC;
    IAccessManagedMSV public cbBTCAccessManagedMSV;
    AccessManager public cbBTCAccessManager;
    IPool public aavePool;
    address public cbBTCWhale;
    address public deployer;
    address public owner;
    address public alice;
    address public test;
    uint256 public initialAmount = 1662;
    uint256 public lockPeriod = 1 weeks;
    uint256 public alicePrivateKey;

    // Base Sepolia addresses
    address constant CB_BTC_TOKEN_ADDRESS = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf; // cbBTC Base Sepolia
    // address constant CB_BTC_AAVE_POOL_ADDRESS = 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b; // Aave pool address for cbBTC
    // address constant CB_BTC_WHALE_ADDRESS = 0xFaEc9cDC3Ef75713b48f46057B98BA04885e3391; // cbBTC rich address
    // address constant CB_BTC_ACCESS_MANAGER_ADDRESS = 0x39833372eaF093285abc571860B6317051Ad58fd; // AccessManager address
    // address constant CB_BTC_ACCESS_MANAGED_MSV_ADDRESS = 0xEaC8740c493cD8Cb22E22e79b1a7Bb055Bc9Ef4e; // AccessManagedMSV address
    // address constant DEPLOYER_ADDRESS = 0x76410823009D09b1FD8e607Fd40baA0323b3bC95; // Deployer address

    function setUp() public {
        // Fork base sepolia
        uint256 baseForkBlock = 37_787_176;
        vm.createSelectFork(vm.rpcUrl("base"), baseForkBlock);

        vaquita = VaquitaPool(payable(0x2400B4E44878d25597da16659705F48927cadef1));
        cbBTC = IERC20(CB_BTC_TOKEN_ADDRESS);
        owner = address(this);
        test = address(0xbe9078B15BaA4A7E3A0848A2A4adEf6014B2Dbff);
        (alice, alicePrivateKey) = makeAddrAndKey("alice");
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

        vm.startPrank(test);
        cbBTC.transfer(alice, initialAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        
        // Prepare EIP-712 permit data
        uint256 nonce = IPermit(address(cbBTC)).nonces(alice);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 chainId = block.chainid;
        string memory name = "cbBTC";
        string memory version = "2";
        address verifyingContract = address(cbBTC);
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
        vaquita.deposit(address(cbBTC), initialAmount, lockPeriod, block.timestamp + 1 hours, signature);
        
        // Verify the deposit was successful
        (address positionOwner,,, uint256 shares,,) = vaquita.positions(aliceDepositId);
        assertEq(positionOwner, alice);
        assertGt(shares, 0);
        
        vm.stopPrank();
    }

    function test_DepositWithApproval() public {
        uint256 balanceBefore = cbBTC.balanceOf(test);
        console.log("balanceBefore", balanceBefore);
        uint256 maxAllowance = type(uint256).max;
        console.log("maxAllowance", maxAllowance);
        uint256 shares = deposit(address(cbBTC), test, initialAmount);
        assertGt(shares, 0);
    }
}