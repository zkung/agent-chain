#!/bin/bash

# Agent Chain Network Node Discovery Tool (Fixed Version)
# 发现和监控网络中的所有节点

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
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Configuration
BASE_RPC_PORT=8545
MAX_SCAN_PORTS=10
TIMEOUT=2

# Known node endpoints to check
KNOWN_ENDPOINTS=(
    "localhost:8545"
    "localhost:8546" 
    "localhost:8547"
    "127.0.0.1:8545"
    "127.0.0.1:8546"
    "127.0.0.1:8547"
)

# Check if a node is running on specific endpoint
check_node_endpoint() {
    local endpoint="$1"
    
    # Try HTTP health check first
    if curl -sf --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "http://$endpoint/health" >/dev/null 2>&1; then
        return 0
    fi
    
    # Try basic HTTP connection
    if curl -sf --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "http://$endpoint/" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Get node information
get_node_info() {
    local endpoint="$1"
    
    local response=$(curl -sf --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "http://$endpoint/health" 2>/dev/null || echo "{}")
    
    # Parse response with fallback values
    local node_id="unknown"
    local height="0"
    local peers="0"
    local status="unknown"
    local version="unknown"
    
    if command -v jq >/dev/null 2>&1; then
        node_id=$(echo "$response" | jq -r '.node_id // "unknown"' 2>/dev/null || echo "unknown")
        height=$(echo "$response" | jq -r '.height // "0"' 2>/dev/null || echo "0")
        peers=$(echo "$response" | jq -r '.peers // "0"' 2>/dev/null || echo "0")
        status=$(echo "$response" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
        version=$(echo "$response" | jq -r '.version // "unknown"' 2>/dev/null || echo "unknown")
    else
        # Fallback parsing without jq
        if [[ "$response" == *"node_id"* ]]; then
            status="online"
        fi
    fi
    
    echo "$node_id|$height|$peers|$status|$version"
}

# Scan for nodes on local network
scan_local_network() {
    local found_nodes=()
    
    log_info "扫描本地网络节点..." >&2
    
    # Scan common ports
    for i in $(seq 0 $((MAX_SCAN_PORTS - 1))); do
        local port=$((BASE_RPC_PORT + i))
        local endpoint="localhost:$port"
        
        if check_node_endpoint "$endpoint"; then
            found_nodes+=("$endpoint")
            log_success "发现节点: $endpoint" >&2
        fi
    done
    
    # Output only the found nodes (not log messages)
    printf '%s\n' "${found_nodes[@]}"
}

# Display network topology
display_network_topology() {
    local all_nodes=("$@")
    
    echo "🌐 Agent Chain 网络拓扑 / Network Topology"
    echo "=============================================="
    
    if [[ ${#all_nodes[@]} -eq 0 ]]; then
        echo "⚠️ 未发现任何节点 / No nodes found"
        return 1
    fi
    
    local total_nodes=${#all_nodes[@]}
    local online_nodes=0
    local total_height=0
    local total_peers=0
    
    echo "📊 网络概览 / Network Overview:"
    echo "  • 检查的节点数 / Nodes checked: $total_nodes"
    echo
    
    echo "📋 节点详情 / Node Details:"
    echo "┌──────────────────┬──────────────┬──────────┬────────┬────────────┬──────────┐"
    printf "│ %-16s │ %-12s │ %-8s │ %-6s │ %-10s │ %-8s │\n" "地址/Address" "节点ID/ID" "高度/Height" "对等/Peers" "状态/Status" "版本/Ver"
    echo "├──────────────────┼──────────────┼──────────┼────────┼────────────┼──────────┤"
    
    for node in "${all_nodes[@]}"; do
        if check_node_endpoint "$node"; then
            local info=$(get_node_info "$node")
            local node_id=$(echo "$info" | cut -d'|' -f1)
            local height=$(echo "$info" | cut -d'|' -f2)
            local peers=$(echo "$info" | cut -d'|' -f3)
            local status=$(echo "$info" | cut -d'|' -f4)
            local version=$(echo "$info" | cut -d'|' -f5)
            
            # Truncate long values
            local short_node_id="${node_id:0:12}"
            local short_version="${version:0:8}"
            
            # Status icon
            local status_display="✅ online"
            if [[ "$status" == "unknown" ]]; then
                status_display="⚠️ partial"
            fi
            
            printf "│ %-16s │ %-12s │ %-8s │ %-6s │ %-10s │ %-8s │\n" \
                "$node" "$short_node_id" "$height" "$peers" "$status_display" "$short_version"
            
            ((online_nodes++))
            if [[ "$height" =~ ^[0-9]+$ ]]; then
                total_height=$((total_height + height))
            fi
            if [[ "$peers" =~ ^[0-9]+$ ]]; then
                total_peers=$((total_peers + peers))
            fi
        else
            printf "│ %-16s │ %-12s │ %-8s │ %-6s │ %-10s │ %-8s │\n" \
                "$node" "offline" "N/A" "N/A" "❌ offline" "N/A"
        fi
    done
    
    echo "└──────────────────┴──────────────┴──────────┴────────┴────────────┴──────────┘"
    echo
    
    # Network statistics
    echo "📈 网络统计 / Network Statistics:"
    echo "  • 在线节点 / Online nodes: $online_nodes/$total_nodes"
    echo "  • 总连接数 / Total connections: $total_peers"
    
    if [[ $online_nodes -gt 0 ]]; then
        local avg_height=$((total_height / online_nodes))
        echo "  • 平均区块高度 / Average height: $avg_height"
        if [[ $total_peers -gt 0 ]]; then
            local avg_peers=$((total_peers / online_nodes))
            echo "  • 平均连接数 / Average peers: $avg_peers"
        fi
    fi
    
    # Network health assessment
    echo
    echo "🏥 网络健康评估 / Network Health Assessment:"
    if [[ $online_nodes -eq 0 ]]; then
        echo "❌ 网络离线 - 没有活跃节点"
        echo "❌ Network offline - no active nodes"
        echo
        echo "💡 建议 / Suggestions:"
        echo "  1. 启动节点: ./join-network-smart.sh"
        echo "  2. 或使用: ./bootstrap.sh"
        echo "  3. 检查进程: ps aux | grep node"
    elif [[ $online_nodes -eq 1 ]]; then
        echo "⚠️ 网络脆弱 - 只有1个活跃节点"
        echo "⚠️ Network fragile - only 1 active node"
    else
        echo "✅ 网络健康 - $online_nodes个节点在线"
        echo "✅ Network healthy - $online_nodes nodes online"
    fi
}

# Quick node check
quick_check() {
    echo "🔍 快速节点检查 / Quick Node Check"
    echo "================================="
    
    # Check processes
    echo "📋 运行中的进程 / Running Processes:"
    local processes=$(ps aux | grep -E "(node|agent-chain)" | grep -v grep | grep -v discover-nodes || echo "")
    if [[ -n "$processes" ]]; then
        echo "$processes"
    else
        echo "  没有发现相关进程 / No related processes found"
    fi
    echo
    
    # Check ports
    echo "🔌 端口占用情况 / Port Usage:"
    local ports=$(netstat -tlnp 2>/dev/null | grep -E "(8545|8546|8547|9001|9002|9003)" || echo "")
    if [[ -n "$ports" ]]; then
        echo "$ports"
    else
        echo "  没有发现相关端口占用 / No related ports in use"
    fi
    echo
    
    # Test direct connections
    echo "🌐 直接连接测试 / Direct Connection Test:"
    for endpoint in "${KNOWN_ENDPOINTS[@]}"; do
        if check_node_endpoint "$endpoint"; then
            echo "  ✅ $endpoint - 在线 / Online"
        else
            echo "  ❌ $endpoint - 离线 / Offline"
        fi
    done
}

# Show usage
show_usage() {
    echo "Agent Chain Network Node Discovery Tool (Fixed)"
    echo
    echo "用法 / Usage: $0 [COMMAND]"
    echo
    echo "命令 / Commands:"
    echo "  scan       扫描并显示所有网络节点 / Scan and display all network nodes"
    echo "  quick      快速检查节点状态 / Quick node status check"
    echo "  help       显示帮助信息 / Show help information"
    echo
    echo "示例 / Examples:"
    echo "  $0 scan"
    echo "  $0 quick"
}

# Main function
main() {
    local command="${1:-scan}"
    
    case "$command" in
        scan)
            echo "🔍 扫描 Agent Chain 网络节点"
            echo "🔍 Scanning Agent Chain Network Nodes"
            echo
            
            # Collect all unique endpoints
            local all_nodes=()
            
            # Add known endpoints
            all_nodes+=("${KNOWN_ENDPOINTS[@]}")
            
            # Add locally discovered nodes (redirect stderr to avoid mixing with output)
            local local_nodes
            local_nodes=($(scan_local_network 2>/dev/null))
            all_nodes+=("${local_nodes[@]}")
            
            # Remove duplicates and sort
            local unique_nodes=($(printf '%s\n' "${all_nodes[@]}" | sort -u))
            
            # Display results
            display_network_topology "${unique_nodes[@]}"
            ;;
        quick)
            quick_check
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo "未知命令 / Unknown command: $command"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
