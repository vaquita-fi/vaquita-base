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
    address constant WETH_TOKEN = 0x4200000000000000000000000000000000000006; // Base Sepolia WETH
    address constant USDC_ACCESS_MANAGED_MSV_ADDRESS = 0x040AF24f0Ca02cF0ce03ef2f9bcfB32724b2d84F; // AccessManagedMSV address
    // address constant ACCESS_MANAGED_MSV_ADDRESS = 0x37db614aD7659750686a25933cB329CA3D90BD3f; // AccessManagedMSV address
    uint256 lockPeriod = 1 days;

    function setUp() public {
        // Fork base sepolia
        uint256 baseSepoliaForkBlock = 32_214_235;
        vm.createSelectFork(vm.rpcUrl("base-sepolia"), baseSepoliaForkBlock);
    }

    function test_VaquitaPoolProxyDeploymentAndUpgrade() public {
        VaquitaPool implementation = new VaquitaPool();
        address[] memory assets = new address[](1);
        assets[0] = address(USDC_TOKEN);
        address[] memory msvAddresses = new address[](1);
        msvAddresses[0] = address(USDC_ACCESS_MANAGED_MSV_ADDRESS);
        uint256[] memory lockPeriodsArr = new uint256[](1);
        lockPeriodsArr[0] = lockPeriod;
        address owner = makeAddr("owner");
        bytes memory initData = abi.encodeWithSelector(
            implementation.initialize.selector,
            assets,
            msvAddresses,
            lockPeriodsArr,
            address(WETH_TOKEN),
            owner            
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            initData
        );
        vm.stopPrank();
        VaquitaPool proxied = VaquitaPool(payable(address(proxy)));
        assertEq(proxied.isSupportedLockPeriod(lockPeriod, address(USDC_TOKEN)), true, "Lock period should be set");

        address proxyAdminAddress = _getProxyAdmin(address(proxy));
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        VaquitaPool newImpl = new VaquitaPool();
        vm.startPrank(owner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(newImpl),
            ""
        );
        vm.stopPrank();
        assertEq(proxyAdmin.owner(), owner, "ProxyAdmin owner should be test contract");
        assertEq(proxied.isSupportedLockPeriod(lockPeriod, address(USDC_TOKEN)), true, "Lock period should still be set after upgrade");
        (,address msvAddress, VaquitaPool.AssetStatus status,) = proxied.assets(address(USDC_TOKEN));
        assertEq(uint256(status), uint256(VaquitaPool.AssetStatus.Active), "token should be set");
        assertEq(msvAddress, USDC_ACCESS_MANAGED_MSV_ADDRESS, "accessManagedMSV should be set");
    }
}