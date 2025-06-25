#!/bin/bash

# Agent Chain - 智能一键加入网络脚本
# Smart One-Click Network Join Script

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
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Welcome message
show_welcome() {
    echo
    echo "🌐 =================================="
    echo "   Agent Chain - 智能一键加入网络"
    echo "   Smart One-Click Network Join"
    echo "=================================="
    echo
    log_info "欢迎使用 Agent Chain！"
    log_info "Welcome to Agent Chain!"
    echo
}

# Detect project structure
detect_project_structure() {
    log_step "检测项目结构 / Detecting project structure..."
    
    # Check for different possible structures
    if [[ -d "$PROJECT_ROOT/cmd/node" ]] && [[ -d "$PROJECT_ROOT/cmd/wallet" ]]; then
        echo "standard"
        return 0
    elif [[ -f "$PROJECT_ROOT/main.go" ]]; then
        echo "single"
        return 0
    elif [[ -f "$PROJECT_ROOT/node" ]] || [[ -f "$PROJECT_ROOT/node.exe" ]]; then
        echo "prebuilt"
        return 0
    elif [[ -f "$PROJECT_ROOT/bootstrap.sh" ]]; then
        echo "bootstrap"
        return 0
    else
        echo "unknown"
        return 1
    fi
}

# Build project based on structure
build_project() {
    local structure="$1"
    
    log_step "构建项目 / Building project (structure: $structure)..."
    
    cd "$PROJECT_ROOT"
    
    case "$structure" in
        "standard")
            log_info "标准Go项目结构 / Standard Go project structure"
            if [[ ! -f "node" ]]; then
                go build -o node ./cmd/node
                log_success "节点程序构建完成 / Node binary built"
            fi
            if [[ ! -f "wallet" ]]; then
                go build -o wallet ./cmd/wallet
                log_success "钱包程序构建完成 / Wallet binary built"
            fi
            ;;
        "single")
            log_info "单文件Go项目 / Single file Go project"
            if [[ ! -f "agent-chain" ]]; then
                go build -o agent-chain .
                log_success "程序构建完成 / Binary built"
            fi
            ;;
        "prebuilt")
            log_info "预构建二进制文件 / Pre-built binaries found"
            log_success "无需构建 / No build needed"
            ;;
        "bootstrap")
            log_info "使用bootstrap脚本 / Using bootstrap script"
            if [[ -x "bootstrap.sh" ]]; then
                ./bootstrap.sh
                log_success "Bootstrap完成 / Bootstrap completed"
            else
                chmod +x bootstrap.sh
                ./bootstrap.sh
                log_success "Bootstrap完成 / Bootstrap completed"
            fi
            ;;
        *)
            log_error "未知项目结构 / Unknown project structure"
            return 1
            ;;
    esac
}

# Find executable binaries
find_binaries() {
    local node_binary=""
    local wallet_binary=""
    
    # Look for node binary
    for name in "node" "node.exe" "agent-chain" "agent-chain.exe"; do
        if [[ -f "$PROJECT_ROOT/$name" ]]; then
            node_binary="$PROJECT_ROOT/$name"
            break
        fi
    done
    
    # Look for wallet binary
    for name in "wallet" "wallet.exe" "agent-chain" "agent-chain.exe"; do
        if [[ -f "$PROJECT_ROOT/$name" ]]; then
            wallet_binary="$PROJECT_ROOT/$name"
            break
        fi
    done
    
    echo "$node_binary|$wallet_binary"
}

# Start node
start_node() {
    local binaries="$1"
    local node_binary=$(echo "$binaries" | cut -d'|' -f1)
    
    if [[ -z "$node_binary" ]]; then
        log_error "找不到节点程序 / Node binary not found"
        return 1
    fi
    
    log_step "启动节点 / Starting node..."
    
    # Create data directory
    local data_dir="$PROJECT_ROOT/data/my-node"
    mkdir -p "$data_dir"
    
    # Check if node is already running
    if pgrep -f "$node_binary" >/dev/null; then
        log_info "节点已在运行 / Node is already running"
        return 0
    fi
    
    # Start node
    local log_file="$data_dir/node.log"
    nohup "$node_binary" > "$log_file" 2>&1 &
    local node_pid=$!
    echo "$node_pid" > "$data_dir/node.pid"
    
    # Wait for startup
    log_info "等待节点启动 / Waiting for node to start..."
    sleep 5
    
    # Check if still running
    if kill -0 "$node_pid" 2>/dev/null; then
        log_success "节点启动成功 / Node started successfully (PID: $node_pid)"
        return 0
    else
        log_error "节点启动失败 / Node startup failed"
        log_info "查看日志 / Check logs: $log_file"
        return 1
    fi
}

# Test network connectivity
test_connectivity() {
    log_step "测试网络连接 / Testing network connectivity..."
    
    local ports=(8545 8546 8547 3000)
    local found_port=""
    
    for port in "${ports[@]}"; do
        if curl -sf "http://localhost:$port/health" >/dev/null 2>&1; then
            found_port="$port"
            break
        fi
    done
    
    if [[ -n "$found_port" ]]; then
        log_success "网络连接成功 / Network connection successful"
        log_info "RPC端点 / RPC endpoint: http://localhost:$found_port"
        echo "$found_port"
        return 0
    else
        log_warning "未找到活跃的网络端点 / No active network endpoint found"
        return 1
    fi
}

# Create wallet
create_wallet() {
    local binaries="$1"
    local rpc_port="$2"
    local wallet_binary=$(echo "$binaries" | cut -d'|' -f2)
    
    if [[ -z "$wallet_binary" ]]; then
        log_warning "找不到钱包程序 / Wallet binary not found"
        return 1
    fi
    
    log_step "创建钱包 / Creating wallet..."
    
    # Try to create wallet
    if "$wallet_binary" new --name default 2>/dev/null; then
        log_success "钱包创建成功 / Wallet created successfully"
    else
        log_info "钱包可能已存在 / Wallet may already exist"
    fi
    
    # Try to get balance
    if [[ -n "$rpc_port" ]]; then
        local balance=$("$wallet_binary" balance --account default --rpc "http://localhost:$rpc_port" 2>/dev/null || echo "unknown")
        log_info "钱包余额 / Wallet balance: $balance"
    fi
}

# Show usage instructions
show_instructions() {
    local binaries="$1"
    local rpc_port="$2"
    local node_binary=$(echo "$binaries" | cut -d'|' -f1)
    local wallet_binary=$(echo "$binaries" | cut -d'|' -f2)
    
    echo
    log_success "🎉 Agent Chain 节点部署完成！"
    log_success "🎉 Agent Chain node deployment completed!"
    echo
    echo "📋 常用命令 / Common commands:"
    echo
    
    if [[ -n "$wallet_binary" ]] && [[ -n "$rpc_port" ]]; then
        echo "💰 钱包操作 / Wallet operations:"
        echo "  $wallet_binary balance --account default --rpc http://localhost:$rpc_port"
        echo "  $wallet_binary height --rpc http://localhost:$rpc_port"
        echo
    fi
    
    if [[ -n "$rpc_port" ]]; then
        echo "🔧 网络状态 / Network status:"
        echo "  curl http://localhost:$rpc_port/health"
        echo "  curl http://localhost:$rpc_port/status"
        echo
    fi
    
    if [[ -n "$node_binary" ]]; then
        echo "📁 重要文件 / Important files:"
        echo "  节点程序 / Node binary: $node_binary"
        if [[ -n "$wallet_binary" ]]; then
            echo "  钱包程序 / Wallet binary: $wallet_binary"
        fi
        echo "  数据目录 / Data directory: $PROJECT_ROOT/data/my-node/"
        echo "  日志文件 / Log file: $PROJECT_ROOT/data/my-node/node.log"
        echo
    fi
}

# Main function
main() {
    show_welcome
    
    # Detect project structure
    local structure=$(detect_project_structure)
    if [[ "$structure" == "unknown" ]]; then
        log_error "无法识别项目结构 / Cannot recognize project structure"
        log_info "请确保您在正确的Agent Chain项目目录中"
        log_info "Please ensure you are in the correct Agent Chain project directory"
        echo
        log_info "当前目录内容 / Current directory contents:"
        ls -la
        exit 1
    fi
    
    log_success "检测到项目结构 / Detected project structure: $structure"
    
    # Build project
    if ! build_project "$structure"; then
        log_error "项目构建失败 / Project build failed"
        exit 1
    fi
    
    # Find binaries
    local binaries=$(find_binaries)
    local node_binary=$(echo "$binaries" | cut -d'|' -f1)
    local wallet_binary=$(echo "$binaries" | cut -d'|' -f2)
    
    if [[ -z "$node_binary" ]]; then
        log_error "构建后仍找不到可执行文件 / No executable found after build"
        exit 1
    fi
    
    log_success "找到可执行文件 / Found executables:"
    log_info "  节点程序 / Node: $node_binary"
    if [[ -n "$wallet_binary" ]]; then
        log_info "  钱包程序 / Wallet: $wallet_binary"
    fi
    
    # Start node
    if start_node "$binaries"; then
        # Test connectivity
        local rpc_port=$(test_connectivity)
        
        # Create wallet
        create_wallet "$binaries" "$rpc_port"
        
        # Show instructions
        show_instructions "$binaries" "$rpc_port"
    else
        log_error "节点启动失败 / Node startup failed"
        exit 1
    fi
}

# Run main function
main "$@"
