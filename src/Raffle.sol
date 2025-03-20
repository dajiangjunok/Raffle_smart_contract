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
pragma solidity ^0.8.19;

/**
 * @title A simple Raffle Contract
 * @author  Alivin 虎逼大雄
 * @notice  This contract is for creating a simple raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle {
    error Raffle_NotEnoughEthSent();

    /**Events */
    /**
     * @dev Emitted when a player enters the raffle.
     * @param player The address of the player who entered the raffle.
     */
    event EnterRaffle(address indexed player);

    uint256 private immutable i_entranceFee; // 参与价格
    // storage上记录参与者，因为最终其中中奖的人需要得到奖池的token 因此必须是payable修饰
    address payable[] private s_players;

    constructor(uint256 _entranceFee) {
        i_entranceFee = _entranceFee;
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
    function pickWinner() public {}

    /** getter function */
}
