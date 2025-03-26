-include .env

build:; forge build

deploy-sepolia:
	forge script script/DeployFundMe.s.sol:DeployFundMe --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

	 
	 # ----------------------------
# Foundry 智能合约 Makefile
# 使用前需安装: make, foundry
# ----------------------------

# 基础配置
DAPP := YourProjectName
SRC_DIR := src
TEST_DIR := test
SCRIPT_DIR := script
LIB_DIR := lib
OUT_DIR := out
GAS_REPORT_FILE := gas-report.txt

# 环境变量配置 (通过命令行传递)
# PRIVATE_KEY ?= 
# RPC_URL ?= 
# ETHERSCAN_API_KEY ?= 
# CHAIN_ID ?= 

# 安装依赖 (使用 --no-commit 避免自动提交)
install:
	forge install foundry-rs/forge-std --no-commit
	forge install OpenZeppelin/openzeppelin-contracts --no-commit

# 编译合约
build:
	forge build

# 清理构建产物
clean:
	forge clean
	rm -rf ${OUT_DIR} ${GAS_REPORT_FILE}

# 运行所有测试并生成 Gas 报告
test:
	forge test -vvv --gas-report

# 运行指定测试合约
test-%:
	forge test -vvv --match-test $* 

# 格式化代码
fmt:
	forge fmt

# 静态分析
lint:
	slither ${SRC_DIR} --exclude naming-convention

# 本地节点 (Anvil)
anvil:
	anvil -b 1

# 部署到指定网络 (示例: make deploy network=sepolia)
deploy:
	@forge script ${SCRIPT_DIR}/Deploy.s.sol:DeployScript \
		--rpc-url ${RPC_URL} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		-vvvv

# 验证已部署合约
verify:
	@forge verify-contract \
		--chain-id ${CHAIN_ID} \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		${CONTRACT_ADDRESS} \
		${CONTRACT_NAME}

# 主网分叉测试
fork-test:
	forge test -vvv --fork-url ${RPC_URL}

# 生成存储布局图
storage-layout:
	forge inspect --pretty ${CONTRACT_NAME} storage-layout > storage-layout.md

# 帮助信息
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  install       安装依赖库"
	@echo "  build         编译合约"
	@echo "  test          运行所有测试"
	@echo "  test-<name>   运行指定测试用例"
	@echo "  deploy        部署到指定网络 (需设置 RPC_URL/PRIVATE_KEY)"
	@echo "  verify        验证已部署合约"
	@echo "  fork-test     主网分叉测试"
	@echo "  fmt           格式化代码"
	@echo "  lint          运行静态分析"
	@echo "  clean         清理构建产物"

.PHONY: all install build test clean fmt lint anvil deploy verify fork-test help