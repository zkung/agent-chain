# Agent Chain 公网部署指南

**当前状态**: 🏠 本地运行  
**目标状态**: 🌍 全球访问  
**部署类型**: 生产级公网部署  

## 🎯 部署目标

将Agent Chain主网从本地部署扩展到公网，让全球用户都能访问和使用。

## 🏗️ 部署架构

### 目标架构
```
Internet
    ↓
Load Balancer (Nginx)
    ↓
┌─────────────────────────────────┐
│     Agent Chain Mainnet         │
│  ┌─────────┬─────────┬─────────┐ │
│  │Validator│Validator│Validator│ │
│  │    1    │    2    │    3    │ │
│  │  :8545  │  :8546  │  :8547  │ │
│  └─────────┴─────────┴─────────┘ │
└─────────────────────────────────┘
```

### 公网端点
- **主RPC**: https://rpc.agentchain.io
- **API服务**: https://api.agentchain.io  
- **监控面板**: https://monitor.agentchain.io

## 🚀 部署步骤

### 第一步: 云服务器准备

#### 1.1 选择云服务商
推荐配置：
- **CPU**: 4核心
- **内存**: 8GB RAM
- **存储**: 100GB SSD
- **网络**: 100Mbps带宽
- **系统**: Ubuntu 22.04 LTS

#### 1.2 服务器配置
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装必要软件
sudo apt install -y docker.io docker-compose nginx certbot

# 安装Go语言
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

### 第二步: 项目部署

#### 2.1 上传项目代码
```bash
# 克隆项目
git clone https://github.com/yourusername/agent-chain.git
cd agent-chain

# 构建项目
make build

# 或者使用Docker
docker build -t agentchain/node:latest .
```

#### 2.2 配置环境变量
```bash
# 创建环境配置
cat > .env << EOF
CHAIN_ID=agent-chain-mainnet
GENESIS_TIME=2025-06-25T18:25:13Z
PUBLIC_IP=$(curl -s ifconfig.me)
DOMAIN=agentchain.io
EOF
```

### 第三步: 网络配置

#### 3.1 防火墙设置
```bash
# 配置UFW防火墙
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 8545/tcp    # RPC (可选，通过Nginx代理)
sudo ufw enable
```

#### 3.2 Nginx配置
```nginx
# /etc/nginx/sites-available/agentchain
server {
    listen 80;
    server_name rpc.agentchain.io;
    
    location / {
        proxy_pass http://localhost:8545;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name api.agentchain.io;
    
    location / {
        proxy_pass http://localhost:8546;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

#### 3.3 启用站点
```bash
sudo ln -s /etc/nginx/sites-available/agentchain /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 第四步: SSL证书配置

#### 4.1 获取Let's Encrypt证书
```bash
# 为域名获取SSL证书
sudo certbot --nginx -d rpc.agentchain.io
sudo certbot --nginx -d api.agentchain.io
sudo certbot --nginx -d monitor.agentchain.io

# 设置自动续期
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

### 第五步: 启动主网

#### 5.1 使用Docker Compose
```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  validator1:
    image: agentchain/node:latest
    ports:
      - "8545:8545"
      - "9001:9001"
    volumes:
      - ./data/validator1:/app/data
      - ./genesis:/app/genesis
    environment:
      - NODE_ID=validator1
      - RPC_PORT=8545
      - P2P_PORT=9001
    restart: unless-stopped

  validator2:
    image: agentchain/node:latest
    ports:
      - "8546:8546"
      - "9002:9002"
    volumes:
      - ./data/validator2:/app/data
      - ./genesis:/app/genesis
    environment:
      - NODE_ID=validator2
      - RPC_PORT=8546
      - P2P_PORT=9002
    restart: unless-stopped

  validator3:
    image: agentchain/node:latest
    ports:
      - "8547:8547"
      - "9003:9003"
    volumes:
      - ./data/validator3:/app/data
      - ./genesis:/app/genesis
    environment:
      - NODE_ID=validator3
      - RPC_PORT=8547
      - P2P_PORT=9003
    restart: unless-stopped
```

#### 5.2 启动服务
```bash
# 启动主网
docker-compose -f docker-compose.prod.yml up -d

# 检查状态
docker-compose -f docker-compose.prod.yml ps
```

### 第六步: 域名配置

#### 6.1 DNS设置
在域名服务商配置DNS记录：
```
A    rpc.agentchain.io      -> YOUR_SERVER_IP
A    api.agentchain.io      -> YOUR_SERVER_IP
A    monitor.agentchain.io  -> YOUR_SERVER_IP
```

#### 6.2 验证访问
```bash
# 测试公网访问
curl https://rpc.agentchain.io/health
curl https://api.agentchain.io/status
```

## 🔍 验证部署

### 网络连通性测试
```bash
# 从外部测试RPC访问
curl -X POST https://rpc.agentchain.io \
  -H "Content-Type: application/json" \
  -d '{"method":"eth_blockNumber","params":[],"id":1}'

# 测试健康检查
curl https://rpc.agentchain.io/health
```

### 钱包连接测试
```bash
# 使用公网端点
./wallet height --rpc https://rpc.agentchain.io
./wallet balance --account alice --rpc https://rpc.agentchain.io
```

## 📊 监控配置

### Prometheus + Grafana
```yaml
# monitoring/docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
```

### 告警配置
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'agentchain'
    static_configs:
      - targets: ['localhost:8545', 'localhost:8546', 'localhost:8547']
```

## 🔒 安全配置

### 1. 网络安全
- 使用防火墙限制端口访问
- 配置DDoS防护
- 启用SSL/TLS加密
- 定期安全更新

### 2. 应用安全
- 验证者密钥安全存储
- 定期备份重要数据
- 监控异常活动
- 访问日志记录

### 3. 运维安全
- SSH密钥认证
- 禁用root登录
- 定期安全审计
- 应急响应计划

## 📈 性能优化

### 1. 服务器优化
```bash
# 系统参数优化
echo 'net.core.somaxconn = 65535' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog = 65535' >> /etc/sysctl.conf
sysctl -p
```

### 2. Nginx优化
```nginx
# 性能优化配置
worker_processes auto;
worker_connections 1024;

gzip on;
gzip_comp_level 6;
gzip_types text/plain application/json;

client_max_body_size 100M;
```

### 3. 数据库优化
- 使用SSD存储
- 定期数据清理
- 索引优化
- 连接池配置

## 🎯 部署检查清单

### 部署前检查
- [ ] 服务器配置完成
- [ ] 域名DNS配置
- [ ] SSL证书获取
- [ ] 防火墙配置
- [ ] 监控系统部署

### 部署后验证
- [ ] 网络连通性测试
- [ ] RPC接口测试
- [ ] 钱包连接测试
- [ ] 性能基准测试
- [ ] 安全扫描

### 运维准备
- [ ] 监控告警配置
- [ ] 备份策略实施
- [ ] 应急响应计划
- [ ] 文档更新完成

## 🌍 全球访问

部署完成后，全球用户可以通过以下方式访问：

### 公网端点
- **主RPC**: https://rpc.agentchain.io
- **API服务**: https://api.agentchain.io
- **区块浏览器**: https://explorer.agentchain.io
- **监控面板**: https://monitor.agentchain.io

### 钱包连接
```bash
# 全球用户可以使用
./wallet height --rpc https://rpc.agentchain.io
./wallet new --name myaccount
./wallet balance --account myaccount --rpc https://rpc.agentchain.io
```

---

**部署状态**: 🏠 本地运行 → 🌍 全球访问  
**预计部署时间**: 2-4小时  
**技术支持**: 24/7监控和维护
