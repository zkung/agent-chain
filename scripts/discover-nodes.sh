#!/bin/bash

# Agent Chain Network Node Discovery Tool
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
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_network() { echo -e "${PURPLE}[NETWORK]${NC} $1"; }
log_node() { echo -e "${CYAN}[NODE]${NC} $1"; }

# Configuration
BASE_RPC_PORT=8545
MAX_SCAN_PORTS=20
TIMEOUT=3

# Known node endpoints to check
KNOWN_ENDPOINTS=(
    "localhost:8545"
    "localhost:8546" 
    "localhost:8547"
    "127.0.0.1:8545"
    "127.0.0.1:8546"
    "127.0.0.1:8547"
)

# Public endpoints (if any)
PUBLIC_ENDPOINTS=(
    # Add public endpoints here when available
    # "rpc.agentchain.io:8545"
    # "node1.agentchain.io:8545"
)

# Check if a node is running on specific endpoint
check_node_endpoint() {
    local endpoint="$1"
    local host=$(echo "$endpoint" | cut -d':' -f1)
    local port=$(echo "$endpoint" | cut -d':' -f2)
    
    # Try HTTP health check
    if curl -sf --connect-timeout "$TIMEOUT" "http://$endpoint/health" >/dev/null 2>&1; then
        return 0
    fi
    
    # Try basic TCP connection
    if timeout "$TIMEOUT" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Get node information
get_node_info() {
    local endpoint="$1"
    
    local response=$(curl -sf --connect-timeout "$TIMEOUT" "http://$endpoint/health" 2>/dev/null || echo "{}")
    
    # Parse response
    local node_id=$(echo "$response" | jq -r '.node_id // "unknown"' 2>/dev/null || echo "unknown")
    local height=$(echo "$response" | jq -r '.height // "0"' 2>/dev/null || echo "0")
    local peers=$(echo "$response" | jq -r '.peers // "0"' 2>/dev/null || echo "0")
    local status=$(echo "$response" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
    local version=$(echo "$response" | jq -r '.version // "unknown"' 2>/dev/null || echo "unknown")
    local uptime=$(echo "$response" | jq -r '.uptime // "unknown"' 2>/dev/null || echo "unknown")
    
    echo "$node_id|$height|$peers|$status|$version|$uptime"
}

# Get peer list from a node
get_peer_list() {
    local endpoint="$1"
    
    local response=$(curl -sf --connect-timeout "$TIMEOUT" "http://$endpoint/peers" 2>/dev/null || echo "{}")
    
    # Extract peer addresses
    echo "$response" | jq -r '.peers[]?.address // empty' 2>/dev/null || echo ""
}

# Scan for nodes on local network
scan_local_network() {
    log_network "扫描本地网络节点 / Scanning local network nodes..."
    
    local found_nodes=()
    
    # Scan common ports
    for i in $(seq 0 $((MAX_SCAN_PORTS - 1))); do
        local port=$((BASE_RPC_PORT + i))
        local endpoint="localhost:$port"
        
        if check_node_endpoint "$endpoint"; then
            found_nodes+=("$endpoint")
            log_success "发现节点 / Found node: $endpoint"
        fi
    done
    
    printf '%s\n' "${found_nodes[@]}"
}

# Discover nodes through peer exchange
discover_through_peers() {
    local known_nodes=("$@")
    local discovered_peers=()
    
    log_network "通过对等节点发现网络 / Discovering network through peers..."
    
    for node in "${known_nodes[@]}"; do
        log_info "查询节点 $node 的对等节点列表..."
        
        local peers=$(get_peer_list "$node")
        
        if [[ -n "$peers" ]]; then
            while IFS= read -r peer; do
                if [[ -n "$peer" ]] && [[ ! " ${discovered_peers[@]} " =~ " ${peer} " ]]; then
                    discovered_peers+=("$peer")
                    log_info "发现对等节点 / Discovered peer: $peer"
                fi
            done <<< "$peers"
        fi
    done
    
    printf '%s\n' "${discovered_peers[@]}"
}

# Display network topology
display_network_topology() {
    local all_nodes=("$@")
    
    log_network "🌐 Agent Chain 网络拓扑 / Network Topology"
    echo "=" * 60
    
    if [[ ${#all_nodes[@]} -eq 0 ]]; then
        log_warning "未发现任何活跃节点 / No active nodes found"
        return 1
    fi
    
    local total_nodes=${#all_nodes[@]}
    local total_height=0
    local total_peers=0
    local online_nodes=0
    
    echo "📊 网络概览 / Network Overview:"
    echo "  • 发现的节点数 / Discovered nodes: $total_nodes"
    echo
    
    echo "📋 节点详情 / Node Details:"
    echo "┌─────────────────────────────────────────────────────────────────────────────┐"
    printf "│ %-20s │ %-12s │ %-8s │ %-6s │ %-10s │ %-8s │\n" "节点地址/Address" "节点ID/Node ID" "高度/Height" "对等/Peers" "状态/Status" "版本/Ver"
    echo "├─────────────────────────────────────────────────────────────────────────────┤"
    
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
            local status_icon="✅"
            if [[ "$status" != "ok" ]]; then
                status_icon="⚠️"
            fi
            
            printf "│ %-20s │ %-12s │ %-8s │ %-6s │ %-9s │ %-8s │\n" \
                "$node" "$short_node_id" "$height" "$peers" "$status_icon$status" "$short_version"
            
            ((online_nodes++))
            if [[ "$height" =~ ^[0-9]+$ ]]; then
                total_height=$((total_height + height))
            fi
            if [[ "$peers" =~ ^[0-9]+$ ]]; then
                total_peers=$((total_peers + peers))
            fi
        else
            printf "│ %-20s │ %-12s │ %-8s │ %-6s │ %-10s │ %-8s │\n" \
                "$node" "offline" "N/A" "N/A" "❌ offline" "N/A"
        fi
    done
    
    echo "└─────────────────────────────────────────────────────────────────────────────┘"
    echo
    
    # Network statistics
    echo "📈 网络统计 / Network Statistics:"
    echo "  • 在线节点 / Online nodes: $online_nodes/$total_nodes"
    echo "  • 总连接数 / Total connections: $total_peers"
    
    if [[ $online_nodes -gt 0 ]]; then
        local avg_height=$((total_height / online_nodes))
        local avg_peers=$((total_peers / online_nodes))
        echo "  • 平均区块高度 / Average height: $avg_height"
        echo "  • 平均连接数 / Average peers: $avg_peers"
    fi
    
    # Network health assessment
    echo
    echo "🏥 网络健康评估 / Network Health Assessment:"
    if [[ $online_nodes -eq 0 ]]; then
        log_error "❌ 网络离线 - 没有活跃节点"
        log_error "❌ Network offline - no active nodes"
    elif [[ $online_nodes -eq 1 ]]; then
        log_warning "⚠️ 网络脆弱 - 只有1个活跃节点"
        log_warning "⚠️ Network fragile - only 1 active node"
    elif [[ $total_peers -eq 0 ]]; then
        log_warning "⚠️ 节点孤立 - 节点间无连接"
        log_warning "⚠️ Nodes isolated - no peer connections"
    else
        log_success "✅ 网络健康 - $online_nodes个节点，$total_peers个连接"
        log_success "✅ Network healthy - $online_nodes nodes, $total_peers connections"
    fi
}

# Monitor network in real-time
monitor_network() {
    log_network "📡 实时网络监控 / Real-time Network Monitoring"
    log_info "按 Ctrl+C 停止监控 / Press Ctrl+C to stop monitoring"
    echo
    
    while true; do
        # Clear screen
        clear
        
        echo "🕒 $(date)"
        echo
        
        # Discover all nodes
        local all_nodes=()
        
        # Add known endpoints
        all_nodes+=("${KNOWN_ENDPOINTS[@]}")
        all_nodes+=("${PUBLIC_ENDPOINTS[@]}")
        
        # Add locally discovered nodes
        local local_nodes=($(scan_local_network 2>/dev/null))
        all_nodes+=("${local_nodes[@]}")
        
        # Remove duplicates
        local unique_nodes=($(printf '%s\n' "${all_nodes[@]}" | sort -u))
        
        # Display topology
        display_network_topology "${unique_nodes[@]}"
        
        # Wait before next update
        sleep 5
    done
}

# Export node list
export_node_list() {
    local output_file="${1:-node_list.json}"
    
    log_network "导出节点列表 / Exporting node list to $output_file"
    
    # Discover all nodes
    local all_nodes=()
    all_nodes+=("${KNOWN_ENDPOINTS[@]}")
    all_nodes+=("${PUBLIC_ENDPOINTS[@]}")
    
    local local_nodes=($(scan_local_network 2>/dev/null))
    all_nodes+=("${local_nodes[@]}")
    
    # Remove duplicates
    local unique_nodes=($(printf '%s\n' "${all_nodes[@]}" | sort -u))
    
    # Create JSON output
    echo "{" > "$output_file"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$output_file"
    echo "  \"total_nodes\": ${#unique_nodes[@]}," >> "$output_file"
    echo "  \"nodes\": [" >> "$output_file"
    
    local first=true
    for node in "${unique_nodes[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$output_file"
        fi
        
        echo -n "    {" >> "$output_file"
        echo -n "\"endpoint\": \"$node\"" >> "$output_file"
        
        if check_node_endpoint "$node"; then
            local info=$(get_node_info "$node")
            local node_id=$(echo "$info" | cut -d'|' -f1)
            local height=$(echo "$info" | cut -d'|' -f2)
            local peers=$(echo "$info" | cut -d'|' -f3)
            local status=$(echo "$info" | cut -d'|' -f4)
            
            echo -n ", \"status\": \"online\"" >> "$output_file"
            echo -n ", \"node_id\": \"$node_id\"" >> "$output_file"
            echo -n ", \"height\": $height" >> "$output_file"
            echo -n ", \"peers\": $peers" >> "$output_file"
            echo -n ", \"node_status\": \"$status\"" >> "$output_file"
        else
            echo -n ", \"status\": \"offline\"" >> "$output_file"
        fi
        
        echo -n "}" >> "$output_file"
    done
    
    echo "" >> "$output_file"
    echo "  ]" >> "$output_file"
    echo "}" >> "$output_file"
    
    log_success "节点列表已导出到 / Node list exported to: $output_file"
}

# Show usage
show_usage() {
    echo "Agent Chain Network Node Discovery Tool"
    echo
    echo "用法 / Usage: $0 [COMMAND]"
    echo
    echo "命令 / Commands:"
    echo "  scan       扫描并显示所有网络节点 / Scan and display all network nodes"
    echo "  monitor    实时监控网络状态 / Real-time network monitoring"
    echo "  export     导出节点列表到JSON文件 / Export node list to JSON file"
    echo "  help       显示帮助信息 / Show help information"
    echo
    echo "示例 / Examples:"
    echo "  $0 scan"
    echo "  $0 monitor"
    echo "  $0 export nodes.json"
}

# Main function
main() {
    local command="${1:-scan}"
    
    case "$command" in
        scan)
            log_network "🔍 扫描 Agent Chain 网络节点"
            log_network "🔍 Scanning Agent Chain Network Nodes"
            echo
            
            # Discover all nodes
            local all_nodes=()
            all_nodes+=("${KNOWN_ENDPOINTS[@]}")
            all_nodes+=("${PUBLIC_ENDPOINTS[@]}")
            
            local local_nodes=($(scan_local_network))
            all_nodes+=("${local_nodes[@]}")
            
            # Remove duplicates
            local unique_nodes=($(printf '%s\n' "${all_nodes[@]}" | sort -u))
            
            # Display results
            display_network_topology "${unique_nodes[@]}"
            ;;
        monitor)
            monitor_network
            ;;
        export)
            export_node_list "$2"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "未知命令 / Unknown command: $command"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo; log_info "节点发现停止 / Node discovery stopped"; exit 0' INT

# Run main function
main "$@"
