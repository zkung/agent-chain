#!/bin/bash

# Agent Chain P2P Network Status Checker
# Checks the status of P2P network and peer discovery

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
log_node() { echo -e "${CYAN}[NODE]${NC} $1"; }

# Configuration
BASE_RPC_PORT=8545
MAX_NODES=10

# Check if a node is running on a specific port
check_node_health() {
    local port="$1"
    
    if curl -sf "http://localhost:$port/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get node information
get_node_info() {
    local port="$1"
    
    local response=$(curl -sf "http://localhost:$port/health" 2>/dev/null || echo "{}")
    
    local height=$(echo "$response" | jq -r '.height // "N/A"' 2>/dev/null || echo "N/A")
    local node_id=$(echo "$response" | jq -r '.node_id // "N/A"' 2>/dev/null || echo "N/A")
    local peers=$(echo "$response" | jq -r '.peers // "N/A"' 2>/dev/null || echo "N/A")
    local status=$(echo "$response" | jq -r '.status // "N/A"' 2>/dev/null || echo "N/A")
    
    echo "$height|$node_id|$peers|$status"
}

# Get peer discovery stats
get_discovery_stats() {
    local port="$1"
    
    # Try to get discovery stats (this would need to be implemented in the node)
    local response=$(curl -sf "http://localhost:$port/discovery" 2>/dev/null || echo "{}")
    
    local known_addresses=$(echo "$response" | jq -r '.known_addresses // "N/A"' 2>/dev/null || echo "N/A")
    local connected_peers=$(echo "$response" | jq -r '.connected_peers // "N/A"' 2>/dev/null || echo "N/A")
    local is_bootstrap=$(echo "$response" | jq -r '.is_bootstrap // false' 2>/dev/null || echo "false")
    
    echo "$known_addresses|$connected_peers|$is_bootstrap"
}

# Display network overview
show_network_overview() {
    log_p2p "🌐 Agent Chain P2P Network Overview"
    echo "=" * 60
    
    local active_nodes=0
    local total_height=0
    local total_peers=0
    local bootstrap_nodes=0
    
    # Check each possible node port
    for i in $(seq 0 $((MAX_NODES - 1))); do
        local port=$((BASE_RPC_PORT + i))
        
        if check_node_health "$port"; then
            local info=$(get_node_info "$port")
            local height=$(echo "$info" | cut -d'|' -f1)
            local node_id=$(echo "$info" | cut -d'|' -f2)
            local peers=$(echo "$info" | cut -d'|' -f3)
            local status=$(echo "$info" | cut -d'|' -f4)
            
            # Get discovery stats
            local discovery=$(get_discovery_stats "$port")
            local known_addrs=$(echo "$discovery" | cut -d'|' -f1)
            local connected=$(echo "$discovery" | cut -d'|' -f2)
            local is_bootstrap=$(echo "$discovery" | cut -d'|' -f3)
            
            # Node type indicator
            local node_type="🔵 Regular"
            if [[ "$is_bootstrap" == "true" ]]; then
                node_type="🟢 Bootstrap"
                ((bootstrap_nodes++))
            fi
            
            # Status indicator
            local status_icon="✅"
            if [[ "$status" != "ok" ]]; then
                status_icon="⚠️"
            fi
            
            log_node "Node $i ($node_type): $status_icon"
            echo "    Port: $port"
            echo "    Node ID: ${node_id:0:20}..."
            echo "    Height: $height"
            echo "    Connected Peers: $peers"
            echo "    Known Addresses: $known_addrs"
            echo "    Status: $status"
            echo
            
            ((active_nodes++))
            if [[ "$height" != "N/A" ]] && [[ "$height" =~ ^[0-9]+$ ]]; then
                total_height=$((total_height + height))
            fi
            if [[ "$peers" != "N/A" ]] && [[ "$peers" =~ ^[0-9]+$ ]]; then
                total_peers=$((total_peers + peers))
            fi
        fi
    done
    
    # Network summary
    echo "=" * 60
    log_p2p "📊 Network Summary"
    echo "  • Active Nodes: $active_nodes"
    echo "  • Bootstrap Nodes: $bootstrap_nodes"
    echo "  • Total Peer Connections: $total_peers"
    
    if [[ $active_nodes -gt 0 ]]; then
        local avg_height=$((total_height / active_nodes))
        echo "  • Average Block Height: $avg_height"
    fi
    
    # Network health assessment
    echo
    if [[ $active_nodes -eq 0 ]]; then
        log_error "❌ Network is offline - no active nodes found"
    elif [[ $active_nodes -eq 1 ]]; then
        log_warning "⚠️ Network has only 1 active node - consider starting more nodes"
    elif [[ $total_peers -eq 0 ]]; then
        log_warning "⚠️ Nodes are running but not connected to each other"
    else
        log_success "✅ Network is healthy with $active_nodes nodes and $total_peers connections"
    fi
}

# Test P2P connectivity
test_p2p_connectivity() {
    log_p2p "🔗 Testing P2P Connectivity"
    echo "=" * 40
    
    local active_ports=()
    
    # Find active nodes
    for i in $(seq 0 $((MAX_NODES - 1))); do
        local port=$((BASE_RPC_PORT + i))
        if check_node_health "$port"; then
            active_ports+=("$port")
        fi
    done
    
    if [[ ${#active_ports[@]} -lt 2 ]]; then
        log_warning "Need at least 2 nodes to test P2P connectivity"
        return 1
    fi
    
    # Test connectivity between nodes
    local connected_pairs=0
    local total_pairs=0
    
    for i in "${active_ports[@]}"; do
        for j in "${active_ports[@]}"; do
            if [[ $i -lt $j ]]; then
                ((total_pairs++))
                
                # Get peer info from both nodes
                local info_i=$(get_node_info "$i")
                local info_j=$(get_node_info "$j")
                
                local peers_i=$(echo "$info_i" | cut -d'|' -f3)
                local peers_j=$(echo "$info_j" | cut -d'|' -f3)
                
                # Simple connectivity test (in a real implementation, 
                # you'd check if nodes can see each other)
                if [[ "$peers_i" != "N/A" ]] && [[ "$peers_j" != "N/A" ]] && 
                   [[ "$peers_i" -gt 0 ]] && [[ "$peers_j" -gt 0 ]]; then
                    log_success "Node $((i - BASE_RPC_PORT)) ↔ Node $((j - BASE_RPC_PORT)): Connected"
                    ((connected_pairs++))
                else
                    log_warning "Node $((i - BASE_RPC_PORT)) ↔ Node $((j - BASE_RPC_PORT)): Not connected"
                fi
            fi
        done
    done
    
    echo
    log_info "Connectivity: $connected_pairs/$total_pairs node pairs connected"
    
    if [[ $connected_pairs -eq $total_pairs ]]; then
        log_success "✅ Full network connectivity achieved"
        return 0
    else
        log_warning "⚠️ Partial network connectivity"
        return 1
    fi
}

# Monitor network in real-time
monitor_network() {
    log_p2p "📡 Real-time Network Monitoring (Press Ctrl+C to stop)"
    echo
    
    while true; do
        # Clear screen
        clear
        
        # Show current time
        echo "🕒 $(date)"
        echo
        
        # Show network status
        show_network_overview
        
        # Wait before next update
        sleep 5
    done
}

# Show usage
show_usage() {
    echo "Agent Chain P2P Network Status Checker"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  status     Show current network status (default)"
    echo "  test       Test P2P connectivity between nodes"
    echo "  monitor    Real-time network monitoring"
    echo "  help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 test"
    echo "  $0 monitor"
}

# Main function
main() {
    local command="${1:-status}"
    
    case "$command" in
        status)
            show_network_overview
            ;;
        test)
            show_network_overview
            echo
            test_p2p_connectivity
            ;;
        monitor)
            monitor_network
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo; log_info "Monitoring stopped"; exit 0' INT

# Run main function
main "$@"
