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
// constructor 构造器
// receive function (if exists)
// fallback function (if exists)
// external  外部调用函数
// public  公共函数
// internal  内部调用函数
// private  私有函数
// view & pure functions  无副作用函数

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        RaffleState raffleState
    );

    /** Type declarations  */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /**Events */
    /**
     * @dev Emitted when a player enters the raffle.
     * @param player The address of the player who entered the raffle.
     */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

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
    RaffleState private s_raffleState;

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
        s_raffleState = RaffleState.OPEN;
    }

    // 买彩票
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            // 购买raffle的token 不足时报错回滚
            revert Raffle_NotEnoughEthSent(); // revert回滚消耗更少的gas
        }
        if (s_raffleState != RaffleState.OPEN) {
            // 当购买彩票通道状态不是OPEN状态时，回滚
            revert Raffle_RaffleNotOpen();
        }

        s_players.push(payable(msg.sender)); // 将买彩票的人的地址放入数组存储
        // 1.Makes migration easier
        // 2.Makes front end "indexing" easier
        // Emit an event to notify that a player has entered the raffle
        emit EnteredRaffle(msg.sender);
    }

    /**
     * when is the winner supposed to be picked?
     * @dev This is the function that the Chainlink Automation nodes call
     * to see if it's time to perform an upkeep.(校验chainlink 的自动脚本是否执行)
     * The following should be true in order to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The raffle is in the OPEN state.
     * 3. The contract has ETH (which means players can enter).
     * 4. (Additional) There is a player and an amount of ETH sent to the contract
     *      that players can enter.
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = (s_players.length > 0);
        return (timeHasPassed && isOpen && hasBalance && hasPlayers, "0x0 ");
    }

    // 开奖
    // 1. get a random number
    // 2. use the random number to pick a player.
    // 3. be automatically called 自动执行
    function performUpkeep(bytes calldata /** performData */) external {
        // check to see if enough time has passed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                RaffleState(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
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

    // CEI: Check Effects Interactions (开发方式，步骤)
    // 该函数调用chainlink 获取随机数， override重写这个函数
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        // Checks
        // Effects (Our own contract)
        // 除模参与人得到0-参与人长度的索引值，然后选中参与者数组里的人
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0); // 重置参与者
        s_lastTimeStamp = block.timestamp;

        // Interactions (Other contracts)
        // 将链上资金都给获胜者
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            // 失败的话回滚
            revert Raffle_TransferFailed();
        }

        // 发送获胜者通知
        emit WinnerPicked(s_recentWinner);
    }

    /** getter function */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }
}
