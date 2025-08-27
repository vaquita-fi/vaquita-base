// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {VaquitaPool} from "../src/VaquitaPool.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployVaquitaPoolBaseSepoliaScript is Script {
    function run() public returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        address accessManagedMSV = address(0x37db614aD7659750686a25933cB329CA3D90BD3f); // AccessManagedMSV address
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        VaquitaPool implementation = new VaquitaPool();
        console.log("VaquitaPool implementation:", address(implementation));

        // Encode initializer data
        address token = address(0x036CbD53842c5426634e7929541eC2318f3dCF7e); // Base SepoliaUSDC
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