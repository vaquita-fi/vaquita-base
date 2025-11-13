// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DeployVaquitaPoolBaseSepoliaScript} from "../script/DeployVaquitaPoolBaseSepolia.s.sol";
import {UpgradeVaquitaPoolScript} from "../script/UpgradeVaquitaPool.s.sol";
import {VaquitaPoolScript} from "../script/VaquitaPool.s.sol";
import {TestUtils} from "./TestUtils.sol";

contract ScriptRunTest is TestUtils {

    function setUp() public {
        // Fork base sepolia
        uint256 baseSepoliaForkBlock = 32_108_899;
        vm.createSelectFork(vm.rpcUrl("base-sepolia"), baseSepoliaForkBlock);
    }

    function test_VaquitaPoolProxyScriptRun() public {
        DeployVaquitaPoolBaseSepoliaScript deployVaquitaPoolBaseScript = new DeployVaquitaPoolBaseSepoliaScript();
        address vaquitaPool = deployVaquitaPoolBaseScript.run(0xEaC8740c493cD8Cb22E22e79b1a7Bb055Bc9Ef4e, 0x19B4a4A5766a07c533b7E50b2A387b7c9CF91088, 0x0C3423B77334F8703f8A5DDe8F2E1C01d08C39D6);
        assertNotEq(vaquitaPool, address(0), "Vaquita pool should be deployed");
    }

    function test_VaquitaPoolScriptRun() public {
        VaquitaPoolScript script = new VaquitaPoolScript();
        address vaquitaPool = script.run();
        assertNotEq(vaquitaPool, address(0), "Vaquita pool should be deployed");
    }

    function test_UpgradeVaquitaPoolScriptRun() public {
        DeployVaquitaPoolBaseSepoliaScript deployVaquitaPoolBaseScript = new DeployVaquitaPoolBaseSepoliaScript();
        address vaquitaPool = deployVaquitaPoolBaseScript.run(0xEaC8740c493cD8Cb22E22e79b1a7Bb055Bc9Ef4e, 0x19B4a4A5766a07c533b7E50b2A387b7c9CF91088, 0x0C3423B77334F8703f8A5DDe8F2E1C01d08C39D6);
        assertNotEq(vaquitaPool, address(0), "Vaquita pool should be deployed");

        VaquitaPoolScript vaquitaPoolScript = new VaquitaPoolScript();
        address newVaquitaPool = vaquitaPoolScript.run();
        assertNotEq(newVaquitaPool, address(0), "New vaquita pool should be deployed");

        UpgradeVaquitaPoolScript upgradeVaquitaPoolScript = new UpgradeVaquitaPoolScript();

        address proxyAdminAddress = _getProxyAdmin(address(vaquitaPool));

        // Run the upgrade with the admin private key and address
        address upgradedVaquitaPool = upgradeVaquitaPoolScript.run(proxyAdminAddress, address(vaquitaPool), address(newVaquitaPool));
        assertNotEq(upgradedVaquitaPool, address(0), "Upgraded vaquita pool should be deployed");
    }
} 