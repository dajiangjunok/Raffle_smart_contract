// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 _entranceFee,
            uint256 _interval,
            address _vrfCoordinator,
            bytes32 _gasLane,
            uint64 _subscriptionId,
            uint32 _callbackGasLimit
        ) = helperConfig.activeNetworkConfig();

        if (_subscriptionId == 0) {
            // we are going to need to create a subscription
            // on the vrf coordinator and add the local wallet as a consumer
            // and then come back and update the subscriptionId here
            CreateSubscription createSubscription = new CreateSubscription();
            _subscriptionId = createSubscription.createSubscription(
                _vrfCoordinator
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            _entranceFee,
            _interval,
            _vrfCoordinator,
            _gasLane,
            _subscriptionId,
            _callbackGasLimit
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
