// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VaquitaPool} from "../src/VaquitaPool.sol";
import {IPermit} from "../src/interfaces/IPermit.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
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
    uint256 public initialAmount = 1000;
    uint256 public lockPeriod = 1 weeks;
    uint256 public alicePrivateKey;

    // Base Sepolia addresses
    address constant CB_BTC_TOKEN_ADDRESS = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf; // cbBTC Base Sepolia

    function setUp() public {
        // Fork base sepolia
        uint256 baseForkBlock = 38_068_910;
        vm.createSelectFork(vm.rpcUrl("base"), baseForkBlock);

        vaquita = VaquitaPool(payable(0x2400B4E44878d25597da16659705F48927cadef1));
        cbBTC = IERC20(CB_BTC_TOKEN_ADDRESS);
        owner = address(this);
        test = address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
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
        // NOTE: cbBTC uses standard EIP-2612 permit (v, r, s format), but VaquitaPool's
        // IPermit interface expects bytes memory signature. Since the contract is live,
        // we need to call permit directly before deposit, or use approval.
        // This test demonstrates the correct way to use permit with cbBTC.

        vm.startPrank(test);
        cbBTC.transfer(alice, initialAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        console.log("alice balance", cbBTC.balanceOf(alice));
        
        // Prepare EIP-712 permit data
        uint256 nonce = IERC20Permit(address(cbBTC)).nonces(alice);
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 aliceDepositId = keccak256(abi.encodePacked(alice, vaquita.depositNonces(alice)));
        
        // Get the actual DOMAIN_SEPARATOR from the token and compute the correct hash
        bytes32 tokenDomainSeparator = IERC20Permit(address(cbBTC)).DOMAIN_SEPARATOR();
        
        // Compute the hash using the token's actual domain separator (EIP-712 standard)
        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            alice,
            address(vaquita),
            initialAmount,
            nonce,
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            tokenDomainSeparator,
            structHash
        ));
        
        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);
        
        // Call standard permit directly since cbBTC uses standard EIP-2612 permit
        // VaquitaPool's IPermit interface doesn't match cbBTC's standard permit signature
        IERC20Permit(address(cbBTC)).permit(
            alice,
            address(vaquita),
            initialAmount,
            deadline,
            v,
            r,
            s
        );
        
        // Verify allowance was set
        uint256 allowance = cbBTC.allowance(alice, address(vaquita));
        assertEq(allowance, initialAmount, "Allowance should be set by permit");
        
        // Now make the deposit (empty signature since permit was already called)
        vaquita.deposit(address(cbBTC), initialAmount, lockPeriod, deadline, "");
        
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