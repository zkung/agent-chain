# Agent Chain Testing Guide

## 概述

本文档描述了 Agent Chain 项目的完整测试策略和验证流程，确保实现符合 `SYS-BOOTSTRAP-DEVNET-001` 规格要求。

## 测试层次

### 1. 快速验证测试 (Quick Tests)
**脚本**: `quick_test.sh`
**用途**: 基本功能和结构验证
**执行时间**: < 2 分钟

```bash
chmod +x quick_test.sh
./quick_test.sh
```

**测试内容**:
- 文件结构完整性
- 构建系统功能
- 二进制文件基本功能
- 配置文件生成
- Docker 支持
- 规格符合性
- 资源需求检查
- 跨平台兼容性

### 2. 集成测试 (Integration Tests)
**脚本**: `test_integration.sh`
**用途**: 端到端功能验证
**执行时间**: 5-10 分钟

```bash
# 首先启动测试网络
./bootstrap.sh &
sleep 30

# 运行集成测试
chmod +x test_integration.sh
./test_integration.sh
```

**测试内容**:
- 钱包二进制文件存在性
- RPC 端点可达性
- 账户创建功能
- 账户列表功能
- 余额查询功能
- 交易发送功能
- 补丁提交功能
- 区块链高度查询
- 节点间高度一致性

### 3. 规格验证测试 (Specification Validation)
**脚本**: `validate_spec.py`
**用途**: 严格的规格符合性验证
**执行时间**: 5-15 分钟

```bash
python3 validate_spec.py
```

**测试内容**:
- 文件结构验证
- 构建系统验证
- Bootstrap 脚本执行验证
- RPC 端点健康检查
- 钱包功能完整性验证
- 区块链高度一致性验证

### 4. 性能测试 (Performance Tests)
**脚本**: `performance_test.py`
**用途**: 资源使用和性能验证
**执行时间**: 5-15 分钟

```bash
# 测试 Bootstrap 性能
python3 performance_test.py bootstrap

# 测试运行时性能
python3 performance_test.py runtime 10
```

**测试内容**:
- Bootstrap 执行时间 (≤ 5 分钟)
- 内存使用峰值 (≤ 1GB)
- 进程监控
- 系统资源使用
- 性能报告生成

### 5. 原始规格测试 (Original Spec Tests)
**脚本**: `tests/bootstrap_devnet/test_bootstrap.py`
**用途**: 原始 pytest 测试套件
**执行时间**: 5-10 分钟

```bash
pip install pytest
pytest tests/bootstrap_devnet/test_bootstrap.py -v
```

**测试内容**:
- Bootstrap 脚本发现
- 端口等待功能
- 账户创建验证
- 交易发送验证
- 高度一致性验证

### 6. 综合测试套件 (Comprehensive Test Suite)
**脚本**: `run_all_tests.sh`
**用途**: 完整的测试流程
**执行时间**: 15-30 分钟

```bash
chmod +x run_all_tests.sh
./run_all_tests.sh
```

**测试内容**:
- 静态分析 (go vet, go fmt)
- 构建测试
- 单元测试
- 集成测试
- 规格验证
- 性能测试
- 压力测试
- 测试报告生成

## 测试环境要求

### 系统要求
- **操作系统**: Linux, macOS, 或 Windows (WSL)
- **内存**: 至少 2GB 可用内存
- **磁盘**: 至少 1GB 可用空间
- **网络**: 本地端口 8545-8547, 9001-9003 可用

### 软件依赖
- **Go**: 1.21 或更高版本
- **Python**: 3.7 或更高版本
- **Make**: 构建工具
- **curl**: HTTP 客户端
- **Docker**: (可选) 容器化测试

### Python 包依赖
```bash
pip install psutil requests pytest
```

## 测试执行流程

### 1. 预检查
```bash
# 检查 Go 版本
go version

# 检查 Python 版本
python3 --version

# 检查依赖
make deps
```

### 2. 快速验证
```bash
./quick_test.sh
```

### 3. 完整测试
```bash
./run_all_tests.sh
```

### 4. 手动验证
```bash
# 启动测试网络
./bootstrap.sh

# 在另一个终端中测试钱包
./wallet new --name test
./wallet list
./wallet balance --account test
./wallet height
```

## 测试结果解读

### 成功标准
- ✅ 所有自动化测试通过
- ✅ Bootstrap 时间 ≤ 5 分钟
- ✅ 内存使用 ≤ 1GB
- ✅ 3 个节点成功启动
- ✅ RPC 端点响应正常
- ✅ 钱包所有命令正常工作
- ✅ 节点间区块高度一致

### 常见问题排查

#### 1. 构建失败
```bash
# 清理并重新构建
make clean
go mod tidy
make build
```

#### 2. 端口占用
```bash
# 检查端口占用
netstat -tulpn | grep -E '(8545|8546|8547|9001|9002|9003)'

# 杀死占用进程
pkill -f "bin/node"
```

#### 3. 内存不足
```bash
# 检查系统内存
free -h

# 关闭其他应用程序
```

#### 4. 权限问题
```bash
# 设置脚本权限
chmod +x bootstrap.sh
chmod +x *.sh
chmod +x *.py
```

## 持续集成

### GitHub Actions 配置示例
```yaml
name: Agent Chain Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: actions/setup-go@v2
      with:
        go-version: 1.21
    - name: Run tests
      run: ./run_all_tests.sh
```

### Docker 测试
```bash
# 构建测试镜像
docker build -t agent-chain:test .

# 运行容器化测试
docker-compose up -d
docker-compose exec node1 ./quick_test.sh
docker-compose down
```

## 测试报告

测试完成后，会生成以下报告文件：

- `test_results/TIMESTAMP/test_report.html` - HTML 格式详细报告
- `test_results/TIMESTAMP/summary.txt` - 文本格式摘要
- `performance_report.json` - 性能测试报告
- `coverage.html` - 代码覆盖率报告

## 最佳实践

1. **定期测试**: 每次代码更改后运行快速测试
2. **完整验证**: 发布前运行完整测试套件
3. **性能监控**: 定期运行性能测试确保资源使用合规
4. **文档更新**: 测试失败时更新相关文档
5. **环境隔离**: 使用 Docker 确保测试环境一致性

## 贡献指南

添加新测试时请遵循以下原则：

1. **测试命名**: 使用描述性的测试名称
2. **错误处理**: 提供清晰的错误信息
3. **清理资源**: 确保测试后清理临时文件
4. **文档更新**: 更新本测试指南
5. **兼容性**: 确保跨平台兼容性
