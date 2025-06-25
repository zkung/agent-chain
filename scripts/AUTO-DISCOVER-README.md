# Agent Chain P2P Auto-Discovery Scripts

这两个脚本可以自动发现网络中的P2P节点，并自动修改配置文件以连接到它们。

## 🚀 快速使用

### PowerShell 脚本 (Windows)
```powershell
# 自动发现并更新所有节点配置
.\scripts\auto-discover-p2p.ps1

# 只更新特定节点
.\scripts\auto-discover-p2p.ps1 -TargetNode node2

# 预览更改（不实际修改）
.\scripts\auto-discover-p2p.ps1 -DryRun
```

### Bash 脚本 (Linux/macOS)
```bash
# 自动发现并更新所有节点配置
bash scripts/auto-discover-p2p.sh

# 只更新特定节点
bash scripts/auto-discover-p2p.sh --target-node node2

# 预览更改（不实际修改）
bash scripts/auto-discover-p2p.sh --dry-run
```

## 🔍 脚本功能

### 1. 自动发现P2P节点
- 扫描指定端口范围（默认8545-8550）
- 检测活跃的Agent Chain节点
- 获取节点ID、对等节点数量等信息
- 自动识别Bootstrap节点

### 2. 智能配置更新
- 自动生成正确的multiaddr格式
- 排除自身节点避免循环连接
- 备份原始配置文件
- 验证配置更新是否成功

### 3. 节点重启管理
- 自动重启更新后的节点
- 验证节点重启是否成功
- 检查P2P连接状态

## 📋 详细参数

### PowerShell 参数
```powershell
-ConfigPath <path>      # 配置文件目录 (默认: configs)
-LogPath <path>         # 日志目录 (默认: logs)
-ScanPortStart <port>   # 扫描起始端口 (默认: 8545)
-ScanPortEnd <port>     # 扫描结束端口 (默认: 8550)
-TargetNode <name>      # 指定更新的节点 (如: node2)
-DryRun                 # 预览模式，不实际修改
-Verbose                # 显示详细扫描信息
```

### Bash 参数
```bash
--config-path <path>    # 配置文件目录 (默认: configs)
--log-path <path>       # 日志目录 (默认: logs)
--scan-start <port>     # 扫描起始端口 (默认: 8545)
--scan-end <port>       # 扫描结束端口 (默认: 8550)
--target-node <name>    # 指定更新的节点 (如: node2)
--dry-run              # 预览模式，不实际修改
--verbose              # 显示详细扫描信息
```

## 🎯 使用场景

### 场景1: 新节点加入网络
```bash
# 启动新节点后，自动发现并连接到现有网络
bash scripts/auto-discover-p2p.sh --target-node node3
```

### 场景2: 网络重新配置
```bash
# 重新配置所有节点的P2P连接
bash scripts/auto-discover-p2p.sh --dry-run  # 先预览
bash scripts/auto-discover-p2p.sh            # 实际执行
```

### 场景3: 故障排除
```bash
# 检查当前网络状态
bash scripts/check-p2p-status-updated.sh

# 重新发现并修复连接
bash scripts/auto-discover-p2p.sh --verbose
```

## 📊 输出示例

### 发现阶段
```
[P2P] 🔍 Scanning for active P2P nodes...
[SUCCESS] ✅ Found Bootstrap node: Port 8545, ID: 12D3KooWCWQ7FRpwMPyb..., Peers: 2
[SUCCESS] ✅ Found Node: Port 8546, ID: 12D3KooWR9HjUkoqW8Xt..., Peers: 1
[SUCCESS] ✅ Found Node: Port 8547, ID: 12D3KooWQqx4NgJAshyz..., Peers: 1
[P2P] 🎉 Discovered 3 active P2P nodes
```

### 配置更新阶段
```
[P2P] 📊 Discovered Nodes:
  • Bootstrap - RPC:8545, P2P:9001, Peers:2
    ID: 12D3KooWCWQ7FRpwMPybKUka3HnSFNSZM5NpUzZJFy5L12ayput1
  • Node - RPC:8546, P2P:9002, Peers:1
    ID: 12D3KooWR9HjUkoqW8Xtz88u5R3P5e6x77LiMyKGqeaXQQMuCGdp

[P2P] 🚀 Bootstrap Nodes:
  • /ip4/127.0.0.1/tcp/9001/p2p/12D3KooWCWQ7FRpwMPybKUka3HnSFNSZM5NpUzZJFy5L12ayput1

[P2P] 📝 Updating Configuration Files:
  • node2.yaml
[INFO] 💾 Backup created: configs/node2.yaml.backup.20241225-143022
[SUCCESS] ✅ Configuration updated successfully
```

## 🔧 生成的配置格式

脚本会生成如下格式的配置文件：

```yaml
data_dir: "data/node2"
p2p:
  port: 9002
  is_bootstrap: false
  enable_discovery: true
  boot_nodes:
    - "/ip4/127.0.0.1/tcp/9001/p2p/12D3KooWCWQ7FRpwMPybKUka3HnSFNSZM5NpUzZJFy5L12ayput1"
rpc:
  port: 8546
validator:
  enabled: true
```

## ⚠️ 注意事项

### 安全考虑
1. **备份**: 脚本会自动备份原始配置文件
2. **验证**: 更新后会验证配置文件格式
3. **预览**: 使用 `--dry-run` 可以预览更改

### 网络要求
1. **节点运行**: 需要至少一个节点正在运行
2. **端口访问**: 确保RPC端口可以访问
3. **权限**: 需要读写配置文件的权限

### 故障排除
1. **无法发现节点**: 检查端口范围和节点状态
2. **配置更新失败**: 检查文件权限和格式
3. **重启失败**: 检查进程状态和端口占用

## 🎉 完整工作流程

```bash
# 1. 启动初始网络
bash scripts/bootstrap-p2p-network.sh start

# 2. 检查当前状态
bash scripts/check-p2p-status-updated.sh

# 3. 自动发现并更新配置
bash scripts/auto-discover-p2p.sh

# 4. 验证P2P连接
bash scripts/check-p2p-status-updated.sh test

# 5. 实时监控
bash scripts/check-p2p-status-updated.sh monitor
```

这些脚本让P2P网络的管理变得简单自动化！🚀
