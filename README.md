# ProveabLy Random Raffle Contracts

## About

This code is to create a provably random smart contract lottery.

## What we want it to do?

1. Users can enter by paying for a ticket(用户可以通过购买彩票来参加)

- The ticket fees are going to go to the winner during the draw(彩票费用将在抽奖期间支付给获奖者)

2. After X period of time, the lottery will automatically draw a winner1. And this will be done programmatically(在 X 时间段后，彩票将自动抽取获奖者,且这将通过编程完成)

3. Using Chainlink VRF & Chainlink Automation(使用 Chainlink VRF 和 Chainlink 自动化)

- Chainlink VRF -> Randamness(以此保证随机性)
- Chainlink Automation -> Time based trigger(基于时间触发)

## Test!

1. Write some deploy scripts(编写一些部署脚本)
2. Write our tests(编写我们的测试)
   1. work on a local blockchain(在局部区块链上)
   2. forked Tesnet(在分叉的测试网上)
   3. forked Mainnet(在分叉的主网上)
