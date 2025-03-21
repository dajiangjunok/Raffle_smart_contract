// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A simple Raffle Contract
 * @author  Alivin 虎比大雄
 * @notice  This contract is for creating a simple raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle_NotEnoughEthSent();

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /**Events */
    /**
     * @dev Emitted when a player enters the raffle.
     * @param player The address of the player who entered the raffle.
     */
    event EnterRaffle(address indexed player);

    uint256 private immutable i_entranceFee; // 参与价格
    // @dev Duration of the lottery in seconds
    uint256 private immutable i_interval; // 开奖的时间间隔
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    // storage上记录参与者，因为最终其中中奖的人需要得到奖池的token 因此必须是payable修饰
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner; // 近期获胜者

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_entranceFee = _entranceFee; // 定义参与价格
        i_interval = _interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_gasLane = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
    }

    // 买彩票
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            // 购买raffle的token 不足时报错回滚
            revert Raffle_NotEnoughEthSent(); // revert回滚消耗更少的gas
        }

        s_players.push(payable(msg.sender)); // 将买彩票的人的地址放入数组存储
        // 1.Makes migration easier
        // 2.Makes front end "indexing" easier
        // Emit an event to notify that a player has entered the raffle
        emit EnterRaffle(msg.sender);
    }

    // 开奖
    // 1. get a random number
    // 2. use the random number to pick a player.
    // 3. be automatically called 自动执行
    function pickWinner() external {
        // check to see if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        // 1. request the RNG 请求随机数
        // 2. get the radom number 获取随机数
        i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, // 订阅ID，用于支付随机数生成费用
            REQUEST_CONFIRMATIONS, // 请求确认数，确保随机数生成的安全性requestConfirmations
            i_callbackGasLimit, // 回调函数的最大Gas限制
            NUM_WORDS // 请求的随机数数量
        );
    }

    // 该函数调用chainlink 获取随机数， override重写这个函数
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // 除模参与人得到0-参与人长度的索引值，然后选中参与者数组里的人
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        // 将链上资金都给获胜者
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            // 失败的话回滚
            revert Raffe__TransferFaild();
        }
    }

    /** getter function */
}
