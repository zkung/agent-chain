#!/bin/bash

# Agent Chain P2P Connection Script
# 手动建立节点间的P2P连接

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_p2p() { echo -e "${PURPLE}[P2P]${NC} $1"; }

# Node endpoints
NODES=(
    "localhost:8545"
    "localhost:8546"
    "localhost:8547"
)

# Check node status
check_node() {
    local endpoint="$1"
    
    if curl -sf --connect-timeout 3 "http://$endpoint/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get node info
get_node_info() {
    local endpoint="$1"
    
    local response=$(curl -sf "http://$endpoint/health" 2>/dev/null || echo "{}")
    echo "$response"
}

# Try to connect nodes via RPC
connect_nodes() {
    log_p2p "🔗 尝试建立P2P连接 / Attempting to establish P2P connections"
    echo
    
    # Check all nodes first
    local active_nodes=()
    for node in "${NODES[@]}"; do
        if check_node "$node"; then
            active_nodes+=("$node")
            log_success "节点在线 / Node online: $node"
        else
            log_warning "节点离线 / Node offline: $node"
        fi
    done
    
    if [[ ${#active_nodes[@]} -lt 2 ]]; then
        log_error "需要至少2个节点才能建立连接 / Need at least 2 nodes to establish connections"
        return 1
    fi
    
    echo
    log_info "发现 ${#active_nodes[@]} 个活跃节点 / Found ${#active_nodes[@]} active nodes"
    
    # Get node IDs and P2P addresses
    declare -A node_ids
    declare -A p2p_addrs
    
    for node in "${active_nodes[@]}"; do
        local info=$(get_node_info "$node")
        local node_id=$(echo "$info" | jq -r '.node_id // "unknown"' 2>/dev/null || echo "unknown")
        
        if [[ "$node_id" != "unknown" ]]; then
            node_ids["$node"]="$node_id"
            
            # Calculate P2P port (RPC port + 456)
            local rpc_port=$(echo "$node" | cut -d':' -f2)
            local p2p_port=$((rpc_port + 456))
            p2p_addrs["$node"]="/ip4/127.0.0.1/tcp/$p2p_port/p2p/$node_id"
            
            log_info "节点 $node: ID=${node_id:0:20}..., P2P端口=$p2p_port"
        fi
    done
    
    echo
    log_p2p "尝试通过RPC API建立连接..."
    
    # Try to connect each node to others
    for node1 in "${active_nodes[@]}"; do
        for node2 in "${active_nodes[@]}"; do
            if [[ "$node1" != "$node2" ]]; then
                local p2p_addr="${p2p_addrs[$node2]}"
                
                if [[ -n "$p2p_addr" ]]; then
                    log_info "连接 $node1 到 $node2..."
                    
                    # Try to connect via RPC (this would need to be implemented in the node)
                    local connect_result=$(curl -sf -X POST \
                        -H "Content-Type: application/json" \
                        -d "{\"method\":\"connect_peer\",\"params\":[\"$p2p_addr\"]}" \
                        "http://$node1/rpc" 2>/dev/null || echo "failed")
                    
                    if [[ "$connect_result" != "failed" ]]; then
                        log_success "连接请求已发送 / Connection request sent"
                    else
                        log_warning "连接请求失败 / Connection request failed"
                    fi
                fi
            fi
        done
    done
}

# Monitor connections
monitor_connections() {
    log_p2p "📊 监控P2P连接状态 / Monitoring P2P connection status"
    echo
    
    local max_attempts=12
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        ((attempt++))
        
        echo "检查轮次 $attempt/$max_attempts..."
        
        local total_peers=0
        local connected_nodes=0
        
        for node in "${NODES[@]}"; do
            if check_node "$node"; then
                local info=$(get_node_info "$node")
                local peers=$(echo "$info" | jq -r '.peers // 0' 2>/dev/null || echo "0")
                local height=$(echo "$info" | jq -r '.height // 0' 2>/dev/null || echo "0")
                
                echo "  $node: 对等节点=$peers, 高度=$height"
                
                if [[ "$peers" -gt 0 ]]; then
                    ((connected_nodes++))
                fi
                total_peers=$((total_peers + peers))
            fi
        done
        
        echo "  总连接数: $total_peers, 已连接节点: $connected_nodes"
        
        if [[ $total_peers -gt 0 ]]; then
            log_success "🎉 P2P连接已建立！"
            log_success "🎉 P2P connections established!"
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            echo "  等待5秒后重试..."
            sleep 5
        fi
        echo
    done
    
    log_warning "⚠️ P2P连接建立超时"
    log_warning "⚠️ P2P connection establishment timeout"
    return 1
}

# Restart nodes with P2P enabled
restart_with_p2p() {
    log_p2p "🔄 重启节点并启用P2P发现 / Restarting nodes with P2P discovery"
    
    # This would require stopping and restarting nodes with proper P2P configuration
    log_info "这需要重新配置节点以启用P2P发现功能"
    log_info "建议使用: ./join-network-smart.sh 来启动支持P2P的节点"
    
    echo
    echo "手动重启步骤 / Manual restart steps:"
    echo "1. 停止当前节点 / Stop current nodes"
    echo "2. 使用P2P参数重启 / Restart with P2P parameters"
    echo "3. 等待自动发现 / Wait for automatic discovery"
    
    echo
    echo "推荐命令 / Recommended commands:"
    echo "  ./join-network-smart.sh"
    echo "  或者 / or:"
    echo "  bash scripts/start-p2p-network.sh start --nodes 3"
}

# Show current network status
show_status() {
    log_p2p "📊 当前网络状态 / Current Network Status"
    echo "=" * 50
    
    for node in "${NODES[@]}"; do
        if check_node "$node"; then
            local info=$(get_node_info "$node")
            local node_id=$(echo "$info" | jq -r '.node_id // "unknown"' 2>/dev/null || echo "unknown")
            local peers=$(echo "$info" | jq -r '.peers // 0' 2>/dev/null || echo "0")
            local height=$(echo "$info" | jq -r '.height // 0' 2>/dev/null || echo "0")
            local status=$(echo "$info" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
            
            echo "🟢 $node:"
            echo "   节点ID: ${node_id:0:30}..."
            echo "   对等节点: $peers"
            echo "   区块高度: $height"
            echo "   状态: $status"
        else
            echo "🔴 $node: 离线 / Offline"
        fi
        echo
    done
}

# Main function
main() {
    local command="${1:-status}"
    
    echo "🌐 Agent Chain P2P连接工具"
    echo "🌐 Agent Chain P2P Connection Tool"
    echo "=" * 40
    echo
    
    case "$command" in
        status)
            show_status
            ;;
        connect)
            show_status
            echo
            connect_nodes
            echo
            monitor_connections
            ;;
        monitor)
            monitor_connections
            ;;
        restart)
            restart_with_p2p
            ;;
        *)
            echo "用法 / Usage: $0 {status|connect|monitor|restart}"
            echo
            echo "命令 / Commands:"
            echo "  status   - 显示当前网络状态 / Show current network status"
            echo "  connect  - 尝试建立P2P连接 / Attempt to establish P2P connections"
            echo "  monitor  - 监控连接状态 / Monitor connection status"
            echo "  restart  - 重启节点建议 / Node restart recommendations"
            ;;
    esac
}

# Run main function
main "$@"
