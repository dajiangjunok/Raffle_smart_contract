// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
// import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 _entranceFee; // 参与价格
        uint256 _interval; // 抽奖时间间隔
        address _vrfCoordinator;
        bytes32 _gasLane; // key hash
        uint256 _subscriptionId; // 订阅id
        uint32 _callbackGasLimit;
        address _link;
        uint256 _deployerKey; // deployer私钥
    }

    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            // sepolia 测试网络
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        uint256 deployerKey;
        try vm.envUint("PRIVATE_KEY") {
            deployerKey = vm.envUint("PRIVATE_KEY");
        } catch {
            // 如果环境变量未设置，使用默认值
            deployerKey = DEFAULT_ANVIL_KEY;
        }

        return
            NetworkConfig({
                _entranceFee: 0.01 ether,
                _interval: 30,
                _vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                _gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                _subscriptionId: 6956947356251161658419968968303257189780587510695963065337171002008948327593, // 设置为0，让DeployRaffle脚本自动创建订阅
                _callbackGasLimit: 500000,
                _link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                _deployerKey: deployerKey
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig._vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9; // 1 gwei

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2_5Mock(
                baseFee,
                gasPriceLink,
                1e9
            );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();
        return
            NetworkConfig({
                _entranceFee: 0.01 ether,
                _interval: 30,
                _vrfCoordinator: address(vrfCoordinatorV2Mock),
                _gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                _subscriptionId: 0, // our script will add this
                _callbackGasLimit: 500000,
                _link: address(link),
                _deployerKey: DEFAULT_ANVIL_KEY
            });
    }
}
