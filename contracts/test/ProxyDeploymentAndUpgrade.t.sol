// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {VaquitaPool} from "../src/VaquitaPool.sol";
import {TestUtils} from "./TestUtils.sol";

contract ProxyDeploymentAndUpgradeTest is TestUtils {
    address constant USDC_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Base Sepolia USDC
    address constant AAVE_POOL = 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b; // Base Sepolia Aave V3 Pool
    address constant ACCESS_MANAGED_MSV_ADDRESS = 0x37db614aD7659750686a25933cB329CA3D90BD3f; // AccessManagedMSV address
    uint256 lockPeriod = 1 days;

    function setUp() public {
        uint256 baseSepoliaForkBlock = 30_259_177;
        vm.createSelectFork(vm.rpcUrl("base-sepolia"), baseSepoliaForkBlock);
    }

    function test_VaquitaPoolProxyDeploymentAndUpgrade() public {
        VaquitaPool implementation = new VaquitaPool();
        uint256[] memory lockPeriodsArr = new uint256[](1);
        lockPeriodsArr[0] = lockPeriod;
        bytes memory initData = abi.encodeWithSelector(
            implementation.initialize.selector,
            USDC_TOKEN,
            ACCESS_MANAGED_MSV_ADDRESS,
            lockPeriodsArr
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(this),
            initData
        );
        VaquitaPool proxied = VaquitaPool(address(proxy));
        assertEq(proxied.isSupportedLockPeriod(lockPeriod), true, "Lock period should be set");

        address proxyAdminAddress = _getProxyAdmin(address(proxy));
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        VaquitaPool newImpl = new VaquitaPool();
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(newImpl),
            ""
        );
        assertEq(proxyAdmin.owner(), address(this), "ProxyAdmin owner should be test contract");
        assertEq(proxied.isSupportedLockPeriod(lockPeriod), true, "Lock period should still be set after upgrade");
        assertEq(address(proxied.token()), USDC_TOKEN, "token should be set");
        assertEq(address(proxied.accessManagedMSV()), ACCESS_MANAGED_MSV_ADDRESS, "accessManagedMSV should be set");
    }
}