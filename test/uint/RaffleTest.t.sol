// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

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
    function testCantEnterWhenRaffleIsNotOpen()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep(""); // 执行开奖

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
    }

    /////////////////////////
    // checkUpkeep Tests   //
    /////////////////////////

    // 测试checkUpkeep返回账户资金不足返回false的情况
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + _interval + 1); // 快进时间(快进_interval + 1)百分比超过开奖时间
        vm.roll(block.number + 1); // 递增区块
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep(""); // 调用checkUpkeep函数
        // Assert
        assert(!upkeepNeeded); // 断言upkeepNeeded为false
    }

    // 测试当时间间隔不足时checkUpkeep返回false的情况
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}(); // 调用主合约的 enterRaffle 函数，从而触发事件
        // vm.roll(block.number + 1); // 递增区块
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep(""); // 调用checkUpkeep函数
        // Assert
        assert(!upkeepNeeded); // 断言upkeepNeeded为false
    }

    // 测试当所有参数都满足条件时checkUpkeep返回true的情况
    function testCheckUpkeepReturnsTrueWhenParamsAreGood()
        public
        raffleEnteredAndTimePassed
    {
        // Arrange Modifier
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep(""); // 调用checkUpkeep函数
        // Assert
        assert(upkeepNeeded); // 断言upkeepNeeded为true
    }

    /////////////////////////
    // performUpkeep Tests //
    /////////////////////////

    // 测试performUpkeep可以运行
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEnteredAndTimePassed
    {
        // Arrange
        // Act / Assert
        raffle.performUpkeep(""); // 调用performUpkeep函数
    }

    // 测试performUpkeep回滚
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        // Act / Assert
        raffle.performUpkeep(""); // 调用performUpkeep函数
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // Arrange
        vm.recordLogs();
        raffle.performUpkeep(""); // 调用performUpkeep函数,发送事件得到requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Act
        bytes32 requestId = entries[1].topics[1]; // 第一个事件是requestRandomWords发出的,此处我们重新有发送，topics第0个参数是整个事件
        Raffle.RaffleState rState = raffle.getRaffleState();
        console.log("topics[0]:", vm.toString(entries[1].topics[0]));
        console.log("topics[1]:", vm.toString(entries[1].topics[1]));
        // Assert
        assert(uint256(requestId) > 0); // 断言requestId大于0
        assert(uint256(rState) == 1); // 断言rState等于1
    }

    /////////////////////////
    // fulfillRandomWords  //
    /////////////////////////

    // 测试fulfillRandomWords可以运行
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomNumber
    ) public raffleEnteredAndTimePassed {
        // Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(_vrfCoordinator).fulfillRandomWords(
            randomNumber,
            address(raffle)
        );
        // Act / Assert
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
    {
        // Arrange
        uint256 additionalEntrants = 5; // 添加5个额外的参与者
        uint256 startingIndex = 1; // 从索引1开始(跳过modifier)
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // 生成一个随机的玩家地址
            hoax(player, STARTING_USER_BALANCE); // deal some ETH to player
            raffle.enterRaffle{value: _entranceFee}(); // 调用主合约的 enterRaffle 函数，从而触发事件
        }
        // Act
        vm.warp(block.timestamp + _interval + 1); // 快进时间(快进_interval + 1)百分比超过开奖时间
        vm.roll(block.number + 1); // 递增区块
        vm.recordLogs(); // 记录日志
        raffle.performUpkeep(""); // 调用performUpkeep函数
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Act
        bytes32 requestId = entries[1].topics[1]; // 第一个事件是requestRandomWords发出的,此处我们重新有发送，topics第0个参数是整个事件

        uint256 previousTimeStamp = raffle.s_lastTimeStamp(); // 获取上一次的时间戳
        uint256 prize = raffle.i_entranceFee() * (additionalEntrants + 1); // 计算总奖金
        // 模拟链上调用
        VRFCoordinatorV2Mock(_vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assert(uint256(raffle.getRaffleState()) == 0); // 断言rState等于0
        assert(raffle.getRecentWinner() != address(0)); // 断言recentWinner不等于0
        assert(raffle.getLengthOfPlayers() == 0); // 断言players长度等于0
        assert(raffle.getRecentTimeStamp() > previousTimeStamp); // 断言recentTimeStamp大于previousTimeStamp
        console.log("winner:", uint256(raffle.getRecentWinner().balance));
        console.log("prize:", prize);
        console.log(STARTING_USER_BALANCE);
        assert(
            uint256(raffle.getRecentWinner().balance) ==
                STARTING_USER_BALANCE + prize - raffle.i_entranceFee()
        ); // 断言recentWinner的余额等于priz
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}(); // 调用主合约的 enterRaffle 函数，从而触发事件
        vm.warp(block.timestamp + _interval + 1); // 快进时间(快进_interval + 1)百分比超过开奖时间
        vm.roll(block.number + 1); // 递增区块
        _;
    }
}
