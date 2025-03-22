// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address _vrfCoordinator, , , ) = helperConfig
            .activeNetworkConfig();

        return createSubscription(_vrfCoordinator);
    }

    function createSubscription(
        address _vrfCoordinator
    ) public returns (uint64) {
        console.log("create subscription on ChainId", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("your subId is %s", subId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}
