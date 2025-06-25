# 给脚本执行权限
chmod +x scripts/discover-nodes.sh

# 扫描并显示所有网络节点
bash scripts/discover-nodes.sh scan

# 实时监控网络（每5秒更新）
bash scripts/discover-nodes.sh monitor

# 导出节点列表到JSON文件
bash scripts/discover-nodes.sh export nodes.json

# 查看帮助
bash scripts/discover-nodes.sh help





# 检查本地是否有运行的节点
ps aux | grep node
netstat -tlnp | grep :854

# 查看特定端口的节点
curl http://localhost:8545/health
curl http://localhost:8546/health
curl http://localhost:8547/health


# 给新脚本执行权限
chmod +x scripts/discover-nodes-fixed.sh

# 快速检查当前状态
bash scripts/discover-nodes-fixed.sh quick


Get-Process | Where-Object {$_.ProcessName -like "*node*" -or $_.ProcessName -like "*agent*"}


# 启动P2P网络 (推荐)
bash scripts/bootstrap-p2p-network.sh start

# 检查网络状态
bash scripts/check-p2p-status-updated.sh

# 测试P2P发现
bash scripts/check-p2p-status-updated.sh test

# 实时监控
bash scripts/check-p2p-status-updated.sh monitor

# 停止网络
bash scripts/bootstrap-p2p-network.sh stop