#!/bin/bash

# Agent Chain - 一键加入网络脚本
# One-Click Network Join Script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_network() { echo -e "${PURPLE}[NETWORK]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
NODE_BINARY="$PROJECT_ROOT/node"
WALLET_BINARY="$PROJECT_ROOT/wallet"

# Default configuration
NODE_NAME="${1:-my-node}"
DATA_DIR="$PROJECT_ROOT/data/$NODE_NAME"
P2P_PORT="${2:-9001}"
RPC_PORT="${3:-8545}"

# Welcome message
show_welcome() {
    echo
    echo "🌐 =================================="
    echo "   Agent Chain - 一键加入网络"
    echo "   One-Click Network Join"
    echo "=================================="
    echo
    log_info "欢迎使用 Agent Chain！"
    log_info "Welcome to Agent Chain!"
    echo
    log_info "这个脚本将帮助您："
    log_info "This script will help you:"
    echo "  • 🔧 自动构建和配置节点"
    echo "  • 🌐 自动发现并连接到网络"
    echo "  • 💰 创建您的第一个钱包"
    echo "  • 🚀 开始使用区块链"
    echo
}

# Check system requirements
check_requirements() {
    log_step "检查系统要求 / Checking system requirements..."
    
    # Check Go
    if ! command -v go &> /dev/null; then
        log_error "Go 语言未安装 / Go is not installed"
        log_info "请安装 Go 1.21+ / Please install Go 1.21+"
        log_info "下载地址 / Download: https://golang.org/dl/"
        exit 1
    fi
    
    local go_version=$(go version | grep -o 'go[0-9]\+\.[0-9]\+' | sed 's/go//')
    log_success "Go 版本 / Go version: $go_version"
    
    # Check Git
    if ! command -v git &> /dev/null; then
        log_warning "Git 未安装，但不是必需的 / Git not installed, but not required"
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装 / curl is not installed"
        exit 1
    fi
    
    log_success "系统要求检查通过 / System requirements check passed"
}

# Build project
build_project() {
    log_step "构建 Agent Chain / Building Agent Chain..."
    
    cd "$PROJECT_ROOT"
    
    # Build node
    if [[ ! -f "$NODE_BINARY" ]]; then
        log_info "构建节点程序 / Building node binary..."
        go build -o node ./cmd/node
        log_success "节点程序构建完成 / Node binary built"
    else
        log_info "节点程序已存在 / Node binary already exists"
    fi
    
    # Build wallet
    if [[ ! -f "$WALLET_BINARY" ]]; then
        log_info "构建钱包程序 / Building wallet binary..."
        go build -o wallet ./cmd/wallet
        log_success "钱包程序构建完成 / Wallet binary built"
    else
        log_info "钱包程序已存在 / Wallet binary already exists"
    fi
    
    log_success "构建完成 / Build completed"
}

# Setup node configuration
setup_node_config() {
    log_step "配置节点 / Setting up node configuration..."
    
    # Create data directory
    mkdir -p "$DATA_DIR"
    
    # Create node config
    cat > "$DATA_DIR/config.yaml" << EOF
# Agent Chain Node Configuration
data_dir: "$DATA_DIR"
p2p_port: $P2P_PORT
rpc_port: $RPC_PORT
is_validator: true
enable_discovery: true

# Network settings
network:
  max_peers: 50
  min_peers: 8
  discovery_interval: 30s
  address_exchange_interval: 60s
EOF
    
    log_success "节点配置完成 / Node configuration completed"
    log_info "数据目录 / Data directory: $DATA_DIR"
    log_info "P2P 端口 / P2P port: $P2P_PORT"
    log_info "RPC 端口 / RPC port: $RPC_PORT"
}

# Start node
start_node() {
    log_step "启动节点并加入网络 / Starting node and joining network..."
    
    # Check if port is available
    if netstat -tuln 2>/dev/null | grep -q ":$RPC_PORT "; then
        log_warning "端口 $RPC_PORT 已被占用 / Port $RPC_PORT is already in use"
        log_info "尝试使用下一个可用端口 / Trying next available port..."
        RPC_PORT=$((RPC_PORT + 1))
        P2P_PORT=$((P2P_PORT + 1))
        setup_node_config
    fi
    
    # Start node in background
    local log_file="$DATA_DIR/node.log"
    log_info "启动节点 / Starting node..."
    log_info "日志文件 / Log file: $log_file"
    
    nohup "$NODE_BINARY" --config "$DATA_DIR/config.yaml" --discovery > "$log_file" 2>&1 &
    local node_pid=$!
    echo "$node_pid" > "$DATA_DIR/node.pid"
    
    # Wait for node to start
    log_info "等待节点启动 / Waiting for node to start..."
    local max_wait=30
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        if curl -sf "http://localhost:$RPC_PORT/health" >/dev/null 2>&1; then
            log_success "节点启动成功！/ Node started successfully!"
            break
        fi
        sleep 2
        ((wait_time += 2))
        echo -ne "\r等待中 / Waiting... ${wait_time}s"
    done
    echo
    
    if [[ $wait_time -ge $max_wait ]]; then
        log_error "节点启动超时 / Node startup timeout"
        log_info "请检查日志文件 / Please check log file: $log_file"
        return 1
    fi
    
    # Get node info
    local node_info=$(curl -sf "http://localhost:$RPC_PORT/health" 2>/dev/null || echo "{}")
    local node_id=$(echo "$node_info" | jq -r '.node_id // "unknown"' 2>/dev/null || echo "unknown")
    local height=$(echo "$node_info" | jq -r '.height // "0"' 2>/dev/null || echo "0")
    
    log_success "节点信息 / Node information:"
    echo "  • 节点ID / Node ID: ${node_id:0:20}..."
    echo "  • 当前高度 / Current height: $height"
    echo "  • RPC端点 / RPC endpoint: http://localhost:$RPC_PORT"
    echo "  • 进程ID / Process ID: $node_pid"
}

# Create wallet
create_wallet() {
    log_step "创建钱包 / Creating wallet..."
    
    local wallet_name="default"
    local wallet_data_dir="$DATA_DIR/wallet"
    
    # Create wallet data directory
    mkdir -p "$wallet_data_dir"
    
    # Check if wallet already exists
    if "$WALLET_BINARY" list --data-dir "$wallet_data_dir" 2>/dev/null | grep -q "$wallet_name"; then
        log_info "钱包已存在 / Wallet already exists"
    else
        log_info "创建新钱包 / Creating new wallet..."
        "$WALLET_BINARY" new --name "$wallet_name" --data-dir "$wallet_data_dir"
        log_success "钱包创建完成 / Wallet created successfully"
    fi
    
    # Get wallet address
    local address=$("$WALLET_BINARY" list --data-dir "$wallet_data_dir" | grep "$wallet_name" | awk '{print $2}' || echo "unknown")
    
    log_success "钱包信息 / Wallet information:"
    echo "  • 钱包名称 / Wallet name: $wallet_name"
    echo "  • 钱包地址 / Wallet address: $address"
    echo "  • 数据目录 / Data directory: $wallet_data_dir"
    
    # Save wallet info
    cat > "$DATA_DIR/wallet-info.txt" << EOF
# Agent Chain Wallet Information
Wallet Name: $wallet_name
Wallet Address: $address
Data Directory: $wallet_data_dir
RPC Endpoint: http://localhost:$RPC_PORT
EOF
}

# Check network status
check_network_status() {
    log_step "检查网络状态 / Checking network status..."
    
    local node_info=$(curl -sf "http://localhost:$RPC_PORT/health" 2>/dev/null || echo "{}")
    local height=$(echo "$node_info" | jq -r '.height // "0"' 2>/dev/null || echo "0")
    local peers=$(echo "$node_info" | jq -r '.peers // "0"' 2>/dev/null || echo "0")
    local status=$(echo "$node_info" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
    
    log_success "网络状态 / Network status:"
    echo "  • 区块高度 / Block height: $height"
    echo "  • 连接节点 / Connected peers: $peers"
    echo "  • 节点状态 / Node status: $status"
    
    if [[ "$status" == "ok" ]]; then
        log_success "✅ 成功加入 Agent Chain 网络！"
        log_success "✅ Successfully joined Agent Chain network!"
    else
        log_warning "⚠️ 节点正在同步中 / Node is syncing..."
    fi
}

# Show usage instructions
show_usage_instructions() {
    log_step "使用说明 / Usage instructions..."
    
    echo
    echo "🎉 恭喜！您已成功加入 Agent Chain 网络！"
    echo "🎉 Congratulations! You have successfully joined the Agent Chain network!"
    echo
    echo "📋 常用命令 / Common commands:"
    echo
    echo "💰 钱包操作 / Wallet operations:"
    echo "  # 查看余额 / Check balance"
    echo "  ./wallet balance --account default --data-dir $DATA_DIR/wallet --rpc http://localhost:$RPC_PORT"
    echo
    echo "  # 查看区块高度 / Check block height"
    echo "  ./wallet height --rpc http://localhost:$RPC_PORT"
    echo
    echo "  # 发送交易 / Send transaction"
    echo "  ./wallet send --account default --to ADDRESS --amount 10 --data-dir $DATA_DIR/wallet --rpc http://localhost:$RPC_PORT"
    echo
    echo "🔧 节点管理 / Node management:"
    echo "  # 查看节点状态 / Check node status"
    echo "  curl http://localhost:$RPC_PORT/health"
    echo
    echo "  # 查看日志 / View logs"
    echo "  tail -f $DATA_DIR/node.log"
    echo
    echo "  # 停止节点 / Stop node"
    echo "  kill \$(cat $DATA_DIR/node.pid)"
    echo
    echo "📁 重要文件 / Important files:"
    echo "  • 节点配置 / Node config: $DATA_DIR/config.yaml"
    echo "  • 钱包信息 / Wallet info: $DATA_DIR/wallet-info.txt"
    echo "  • 节点日志 / Node logs: $DATA_DIR/node.log"
    echo "  • 进程ID / Process ID: $DATA_DIR/node.pid"
    echo
}

# Create management script
create_management_script() {
    log_step "创建管理脚本 / Creating management script..."
    
    cat > "$DATA_DIR/manage-node.sh" << 'EOF'
#!/bin/bash

# Agent Chain Node Management Script

DATA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$DATA_DIR")")"
NODE_BINARY="$PROJECT_ROOT/node"
WALLET_BINARY="$PROJECT_ROOT/wallet"

# Load configuration
source "$DATA_DIR/wallet-info.txt" 2>/dev/null || true
RPC_PORT=$(grep "rpc_port:" "$DATA_DIR/config.yaml" | awk '{print $2}')

case "${1:-help}" in
    start)
        echo "Starting node..."
        nohup "$NODE_BINARY" --config "$DATA_DIR/config.yaml" --discovery > "$DATA_DIR/node.log" 2>&1 &
        echo $! > "$DATA_DIR/node.pid"
        echo "Node started. PID: $(cat "$DATA_DIR/node.pid")"
        ;;
    stop)
        if [[ -f "$DATA_DIR/node.pid" ]]; then
            PID=$(cat "$DATA_DIR/node.pid")
            kill "$PID" 2>/dev/null || true
            rm -f "$DATA_DIR/node.pid"
            echo "Node stopped."
        else
            echo "Node is not running."
        fi
        ;;
    status)
        if [[ -f "$DATA_DIR/node.pid" ]] && kill -0 "$(cat "$DATA_DIR/node.pid")" 2>/dev/null; then
            echo "Node is running. PID: $(cat "$DATA_DIR/node.pid")"
            curl -s "http://localhost:$RPC_PORT/health" | jq . 2>/dev/null || echo "RPC not responding"
        else
            echo "Node is not running."
        fi
        ;;
    logs)
        tail -f "$DATA_DIR/node.log"
        ;;
    wallet)
        shift
        "$WALLET_BINARY" "$@" --data-dir "$DATA_DIR/wallet" --rpc "http://localhost:$RPC_PORT"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs|wallet}"
        echo "  start   - Start the node"
        echo "  stop    - Stop the node"
        echo "  status  - Show node status"
        echo "  logs    - Show node logs"
        echo "  wallet  - Run wallet commands"
        echo
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 wallet balance --account default"
        echo "  $0 wallet height"
        ;;
esac
EOF
    
    chmod +x "$DATA_DIR/manage-node.sh"
    log_success "管理脚本创建完成 / Management script created: $DATA_DIR/manage-node.sh"
}

# Cleanup on exit
cleanup() {
    if [[ -n "${node_pid:-}" ]] && kill -0 "$node_pid" 2>/dev/null; then
        log_info "清理资源 / Cleaning up..."
    fi
}

trap cleanup EXIT

# Main function
main() {
    show_welcome
    
    # Parse arguments
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        echo "Usage: $0 [NODE_NAME] [P2P_PORT] [RPC_PORT]"
        echo
        echo "Arguments:"
        echo "  NODE_NAME   Name for your node (default: my-node)"
        echo "  P2P_PORT    P2P port for node communication (default: 9001)"
        echo "  RPC_PORT    RPC port for API access (default: 8545)"
        echo
        echo "Examples:"
        echo "  $0                          # Use defaults"
        echo "  $0 alice-node               # Custom node name"
        echo "  $0 alice-node 9002 8546     # Custom name and ports"
        exit 0
    fi
    
    log_info "节点名称 / Node name: $NODE_NAME"
    log_info "P2P 端口 / P2P port: $P2P_PORT"
    log_info "RPC 端口 / RPC port: $RPC_PORT"
    echo
    
    # Execute steps
    check_requirements
    build_project
    setup_node_config
    start_node
    create_wallet
    check_network_status
    create_management_script
    show_usage_instructions
    
    echo
    log_success "🎉 Agent Chain 节点部署完成！"
    log_success "🎉 Agent Chain node deployment completed!"
    echo
    log_info "您的节点正在运行并已加入网络。"
    log_info "Your node is running and has joined the network."
    echo
    log_info "使用管理脚本 / Use management script:"
    log_info "  $DATA_DIR/manage-node.sh status"
    log_info "  $DATA_DIR/manage-node.sh wallet balance --account default"
    echo
}

# Run main function
main "$@"
