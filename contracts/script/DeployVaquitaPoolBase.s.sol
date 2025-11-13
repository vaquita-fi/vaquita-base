// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {VaquitaPool} from "../src/VaquitaPool.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployVaquitaPoolBaseScript is Script {
    function run(address usdcAccessManagedMSV, address wethAccessManagedMSV, address cbBTCAccessManagedMSV) public returns (address) {
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
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
        lockPeriods[0] = 1 weeks;
        lockPeriods[1] = 90 days;
        lockPeriods[2] = 1 weeks;
        lockPeriods[3] = 90 days;
        lockPeriods[4] = 1 weeks;
        lockPeriods[5] = 90 days;

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