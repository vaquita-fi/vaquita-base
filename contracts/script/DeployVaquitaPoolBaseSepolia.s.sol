// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {VaquitaPool} from "../src/VaquitaPool.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployVaquitaPoolBaseSepoliaScript is Script {
    function run(address usdcAccessManagedMSV, address wethAccessManagedMSV, address usdtAccessManagedMSV) public returns (address) {
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        VaquitaPool implementation = new VaquitaPool();
        console.log("VaquitaPool implementation:", address(implementation));

        // Encode initializer data
        address usdc = address(0x036CbD53842c5426634e7929541eC2318f3dCF7e); // Base Sepolia USDC
        address usdt = address(0x0a215D8ba66387DCA84B284D18c3B4ec3de6E54a); // Base Sepolia USDT
        address weth = address(0x4200000000000000000000000000000000000006); // Base Sepolia WETH
        address eth = address(0);
        
        // Create arrays for the new initialize signature
        address[] memory assets = new address[](6);
        assets[0] = usdc;
        assets[1] = usdc;
        assets[2] = usdt;
        assets[3] = usdt;
        assets[4] = eth;
        assets[5] = eth;
        
        address[] memory msvAddresses = new address[](6);
        msvAddresses[0] = usdcAccessManagedMSV;
        msvAddresses[1] = usdcAccessManagedMSV;
        msvAddresses[2] = usdtAccessManagedMSV;
        msvAddresses[3] = usdtAccessManagedMSV;
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