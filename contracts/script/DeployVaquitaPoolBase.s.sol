// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {VaquitaPool} from "../src/VaquitaPool.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployVaquitaPoolBaseScript is Script {
    function run() public returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        address accessManagedMSV = address(0x2F7b9503D171531907b60D63ea06EAb2643d331c); // AccessManagedMSV address on Base Mainnet
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        VaquitaPool implementation = new VaquitaPool();
        console.log("VaquitaPool implementation:", address(implementation));

        // Encode initializer data
        address token = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // Base Mainnet USDC
        uint256 lockPeriod = 1 weeks;
        uint256[] memory lockPeriods = new uint256[](1);
        lockPeriods[0] = lockPeriod;
        bytes memory initData = abi.encodeWithSelector(
            implementation.initialize.selector,
            token,
            accessManagedMSV,
            lockPeriods
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