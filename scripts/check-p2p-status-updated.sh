#!/bin/bash

# Agent Chain P2P Status Check Script (Updated)
# Checks the status of P2P connections and network health

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
log_p2p() { echo -e "${PURPLE}[P2P]${NC} $1"; }

# Node endpoints
NODES=(
    "localhost:8545"
    "localhost:8546"
    "localhost:8547"
)

# Node types
NODE_TYPES=(
    "Bootstrap"
    "Node"
    "Node"
)

# Check if a node is healthy
check_node_health() {
    local endpoint="$1"
    
    if curl -sf --connect-timeout 3 "http://$endpoint/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get detailed node information
get_node_info() {
    local endpoint="$1"
    
    local response=$(curl -sf --connect-timeout 5 "http://$endpoint/health" 2>/dev/null || echo "{}")
    echo "$response"
}

# Show network overview
show_network_overview() {
    log_p2p "🌐 Agent Chain P2P Network Status Check"
    echo -e "${CYAN}=" * 60 "${NC}"
    
    local healthy_nodes=0
    local total_connections=0
    local node_index=0
    
    for node in "${NODES[@]}"; do
        local node_type="${NODE_TYPES[$node_index]}"
        
        if check_node_health "$node"; then
            local info=$(get_node_info "$node")
            local node_id=$(echo "$info" | jq -r '.node_id // "unknown"' 2>/dev/null || echo "unknown")
            local peers=$(echo "$info" | jq -r '.peers // 0' 2>/dev/null || echo "0")
            local height=$(echo "$info" | jq -r '.height // 0' 2>/dev/null || echo "0")
            local status=$(echo "$info" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
            
            echo -e "${GREEN}🟢 $node_type ($node):${NC}"
            echo "   📋 Node ID: ${node_id:0:40}..."
            echo "   🤝 Connected Peers: $peers"
            echo "   📊 Block Height: $height"
            echo "   ✅ Status: $status"
            
            ((healthy_nodes++))
            if [[ "$peers" =~ ^[0-9]+$ ]]; then
                total_connections=$((total_connections + peers))
            fi
        else
            echo -e "${RED}🔴 $node_type ($node): Offline${NC}"
        fi
        echo
        ((node_index++))
    done
    
    echo -e "${CYAN}=" * 60 "${NC}"
    log_info "📈 Network Summary:"
    echo "   🏥 Healthy Nodes: $healthy_nodes/${#NODES[@]}"
    echo "   🔗 Total P2P Connections: $total_connections"
    
    if [[ $healthy_nodes -eq ${#NODES[@]} ]] && [[ $total_connections -gt 0 ]]; then
        log_success "🎉 P2P network is fully operational!"
        log_success "   ✅ All nodes are healthy and connected"
    elif [[ $healthy_nodes -gt 0 ]] && [[ $total_connections -gt 0 ]]; then
        log_warning "⚠️ P2P network is partially operational"
        log_warning "   - Some nodes may be offline or disconnected"
    elif [[ $healthy_nodes -gt 0 ]]; then
        log_warning "⚠️ Nodes are running but isolated"
        log_warning "   - Check P2P discovery configuration"
    else
        log_error "❌ P2P network is completely down"
        log_error "   - All nodes are offline"
    fi
    
    echo
    log_info "🔧 Troubleshooting commands:"
    echo "   • View logs: tail -f logs/node*.err"
    echo "   • Check configs: ls -la configs/"
    echo "   • Restart network: bash scripts/start-p2p-network.sh restart"
}

# Monitor connections in real-time
monitor_connections() {
    log_p2p "📊 Real-time P2P Network Monitor"
    echo "Press Ctrl+C to stop monitoring..."
    echo
    
    local iteration=0
    while true; do
        ((iteration++))
        clear
        echo -e "${PURPLE}[P2P MONITOR]${NC} Iteration #$iteration - $(date)"
        echo
        show_network_overview
        echo
        echo "🔄 Refreshing in 5 seconds..."
        sleep 5
    done
}

# Test connectivity and discovery
test_discovery() {
    log_p2p "🔍 Testing P2P Discovery Mechanism"
    echo
    
    local active_nodes=()
    local node_ids=()
    
    # Collect active nodes and their IDs
    local node_index=0
    for node in "${NODES[@]}"; do
        if check_node_health "$node"; then
            active_nodes+=("$node")
            local info=$(get_node_info "$node")
            local node_id=$(echo "$info" | jq -r '.node_id // "unknown"' 2>/dev/null || echo "unknown")
            node_ids+=("$node_id")
            
            log_info "✅ ${NODE_TYPES[$node_index]} ($node) is active"
            echo "   Node ID: $node_id"
        else
            log_warning "❌ ${NODE_TYPES[$node_index]} ($node) is offline"
        fi
        ((node_index++))
    done
    
    echo
    
    if [[ ${#active_nodes[@]} -lt 2 ]]; then
        log_error "❌ Discovery test failed: Need at least 2 active nodes"
        return 1
    fi
    
    log_info "🔍 Discovery test results:"
    echo "   • Active nodes: ${#active_nodes[@]}/${#NODES[@]}"
    echo "   • Unique node IDs: ${#node_ids[@]}"
    
    # Check peer connections
    local total_peers=0
    local connected_nodes=0
    
    for i in "${!active_nodes[@]}"; do
        local node="${active_nodes[$i]}"
        local info=$(get_node_info "$node")
        local peers=$(echo "$info" | jq -r '.peers // 0' 2>/dev/null || echo "0")
        
        echo "   • $node: $peers peer(s)"
        
        if [[ "$peers" -gt 0 ]]; then
            ((connected_nodes++))
        fi
        
        if [[ "$peers" =~ ^[0-9]+$ ]]; then
            total_peers=$((total_peers + peers))
        fi
    done
    
    echo
    
    if [[ $connected_nodes -eq ${#active_nodes[@]} ]] && [[ $total_peers -gt 0 ]]; then
        log_success "🎉 P2P Discovery test PASSED!"
        log_success "   ✅ All active nodes are connected to peers"
        log_success "   ✅ Total connections: $total_peers"
    elif [[ $total_peers -gt 0 ]]; then
        log_warning "⚠️ P2P Discovery test PARTIAL"
        log_warning "   - Some nodes are connected ($connected_nodes/${#active_nodes[@]})"
        log_warning "   - Total connections: $total_peers"
    else
        log_error "❌ P2P Discovery test FAILED"
        log_error "   - No peer connections detected"
        log_error "   - Check bootstrap node configuration"
    fi
}

# Main function
main() {
    local command="${1:-overview}"
    
    case "$command" in
        overview|status)
            show_network_overview
            ;;
        monitor)
            monitor_connections
            ;;
        test|discovery)
            test_discovery
            ;;
        help|--help|-h)
            echo -e "${CYAN}Agent Chain P2P Status Checker (Updated)${NC}"
            echo
            echo "Usage: $0 [COMMAND]"
            echo
            echo "Commands:"
            echo "  overview     Show network overview (default)"
            echo "  status       Alias for overview"
            echo "  monitor      Monitor connections in real-time"
            echo "  test         Test P2P discovery mechanism"
            echo "  discovery    Alias for test"
            echo "  help         Show this help message"
            echo
            echo "Examples:"
            echo "  $0                    # Show network overview"
            echo "  $0 monitor            # Real-time monitoring"
            echo "  $0 test               # Test P2P discovery"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
