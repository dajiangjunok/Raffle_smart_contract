// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 _entranceFee;
    uint256 _interval;
    address _vrfCoordinator;
    bytes32 _gasLane;
    uint64 _subscriptionId;
    uint32 _callbackGasLimit;
    address _link;

    address public PLAYER = makeAddr("player"); // cheatCodes
    uint256 public constant STARTING_USER_BALANCE = 10 ether; // 用于初始化测试用户的余额

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            _entranceFee,
            _interval,
            _vrfCoordinator,
            _gasLane,
            _subscriptionId,
            _callbackGasLimit,
            _link
        ) = helperConfig.activeNetworkConfig();

        // 初始化给这些测试玩家一些tokens
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    // 测试初始状态
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /////////////////////////
    // enterRaffle Tests   //
    /////////////////////////
    // 测试用户参与抽奖费用不足情况
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    // function testRaffleIsNotOpenState( ) public {
    //     // Arrange
    //     vm.prank(PLAYER);

    //     // Act / Assert
    // }

    // 测试用户成功参与抽奖
    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        raffle.enterRaffle{value: _entranceFee}(); // pay entrance fee
        assert(raffle.getPlayer(0) == PLAYER);
    }

    // 测试用户参与抽奖后，触发事件
    function testRaffleEmitsEventOnEnter() public {
        // Arrange
        vm.prank(PLAYER); // 指定接下来合约的调用者为模拟的用户
        // Act / Assert
        // 告诉测试框架接下来期望有一个事件被触发，并指定匹配规则其中参数4代表是否是匿名函数，参数5代表事件发出的地址
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER); // 声明期望事件格式，用于实际触发的事件进行匹配
        raffle.enterRaffle{value: _entranceFee}(); // 调用主合约的 enterRaffle 函数，从而触发事件
    }

    // 测试当raffle状态不为OPEN时，用户发送入库
    function testCantEnterWhenRaffleIsNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
        vm.warp(block.timestamp + _interval + 1); // 快进时间(快进_interval + 1)百分比超过开奖时间
        vm.roll(block.number + 1); // 递增区块
        raffle.performUpkeep(""); // 执行开奖

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
    }
}
