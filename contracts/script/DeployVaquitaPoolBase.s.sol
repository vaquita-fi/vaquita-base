// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {VaquitaPool} from "../src/VaquitaPool.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployVaquitaPoolBaseScript is Script {
    function run() public returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        address usdcAccessManagedMSV = address(0x040AF24f0Ca02cF0ce03ef2f9bcfB32724b2d84F); // AccessManagedMSV address for USDC
        address cbBTCAccessManagedMSV = address(0x4f069a9630f6b6ec5541B7B9C07929a26D808048); // AccessManagedMSV address for cbBTC
        address wethAccessManagedMSV = address(0x19B4a4A5766a07c533b7E50b2A387b7c9CF91088); // AccessManagedMSV address for WETH
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        VaquitaPool implementation = new VaquitaPool();
        console.log("VaquitaPool implementation:", address(implementation));

        // Encode initializer data
        address usdc = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // Base USDC
        address cbBTC = address(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf); // Base cbBTC
        address weth = address(0x4200000000000000000000000000000000000006); // Base WETH
        address eth = address(0);
        
        // Create arrays for the new initialize signature
        address[] memory assets = new address[](6);
        assets[0] = usdc;
        assets[1] = usdc;
        assets[2] = cbBTC;
        assets[3] = cbBTC;
        assets[4] = eth;
        assets[5] = eth;
        
        address[] memory msvAddresses = new address[](6);
        msvAddresses[0] = usdcAccessManagedMSV;
        msvAddresses[1] = usdcAccessManagedMSV;
        msvAddresses[2] = cbBTCAccessManagedMSV;
        msvAddresses[3] = cbBTCAccessManagedMSV;
        msvAddresses[4] = wethAccessManagedMSV;
        msvAddresses[5] = wethAccessManagedMSV;
        
        uint256[] memory lockPeriods = new uint256[](6);
        lockPeriods[0] = 1 minutes;
        lockPeriods[1] = 1 weeks;
        lockPeriods[2] = 1 minutes;
        lockPeriods[3] = 1 weeks;
        lockPeriods[4] = 1 minutes;
        lockPeriods[5] = 1 weeks;

        bytes memory initData = abi.encodeWithSelector(
            implementation.initialize.selector,
            assets,
            msvAddresses,
            lockPeriods,
            weth,
            owner
        );

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            initData
        );
        console.log("VaquitaPool proxy:", address(proxy));

        vm.stopBroadcast();

        return address(proxy);
    }
} 