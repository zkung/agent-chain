#!/bin/bash

# Agent Chain P2P Network Bootstrap Script
# Simplified script that uses the verified configuration format

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
NUM_NODES=3
BASE_P2P_PORT=9001
BASE_RPC_PORT=8545

# Parse command line arguments
COMMAND="${1:-start}"

# Create configuration files
create_configs() {
    log_info "Creating configuration files..."
    
    mkdir -p "$PROJECT_ROOT/configs"
    
    # Node 1 (Bootstrap node)
    cat > "$PROJECT_ROOT/configs/node1.yaml" << EOF
data_dir: "data/node1"
p2p:
  port: 9001
  is_bootstrap: true
  enable_discovery: true
rpc:
  port: 8545
validator:
  enabled: true
EOF
    
    # Node 2 and 3 will be updated with bootstrap node ID later
    for i in {2..3}; do
        local p2p_port=$((9000 + i))
        local rpc_port=$((8544 + i))
        
        cat > "$PROJECT_ROOT/configs/node$i.yaml" << EOF
data_dir: "data/node$i"
p2p:
  port: $p2p_port
  is_bootstrap: false
  enable_discovery: true
  boot_nodes:
    - "/ip4/127.0.0.1/tcp/9001"
rpc:
  port: $rpc_port
validator:
  enabled: true
EOF
    done
    
    log_success "Configuration files created"
}

# Start a single node
start_node() {
    local node_num="$1"
    local config_file="$PROJECT_ROOT/configs/node$node_num.yaml"
    local log_file="$PROJECT_ROOT/logs/node$node_num.log"
    local err_file="$PROJECT_ROOT/logs/node$node_num.err"
    
    # Create logs directory
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Start node
    log_info "Starting node $node_num..."
    cd "$PROJECT_ROOT"
    go run cmd/node/main.go --config "$config_file" > "$log_file" 2> "$err_file" &
    
    local node_pid=$!
    echo "$node_pid" > "$PROJECT_ROOT/logs/node$node_num.pid"
    
    # Wait for node to start
    sleep 5
    
    # Check if node is running
    if ! kill -0 "$node_pid" 2>/dev/null; then
        log_error "Node $node_num failed to start"
        echo "=== Error log ==="
        cat "$err_file" 2>/dev/null || echo "No error log"
        return 1
    fi
    
    log_success "Node $node_num started (PID: $node_pid)"
    return 0
}

# Update node configs with bootstrap node ID
update_configs_with_bootstrap_id() {
    local bootstrap_node_id="$1"
    
    log_info "Updating node configs with bootstrap node ID: $bootstrap_node_id"
    
    for i in {2..3}; do
        local p2p_port=$((9000 + i))
        local rpc_port=$((8544 + i))
        
        cat > "$PROJECT_ROOT/configs/node$i.yaml" << EOF
data_dir: "data/node$i"
p2p:
  port: $p2p_port
  is_bootstrap: false
  enable_discovery: true
  boot_nodes:
    - "/ip4/127.0.0.1/tcp/9001/p2p/$bootstrap_node_id"
rpc:
  port: $rpc_port
validator:
  enabled: true
EOF
    done
    
    log_success "Node configs updated with bootstrap node ID"
}

# Start the P2P network
start_network() {
    log_p2p "🚀 Starting Agent Chain P2P Network"
    echo -e "${CYAN}=" * 50 "${NC}"
    
    # Create configs
    create_configs
    
    # Start bootstrap node (node 1)
    if ! start_node 1; then
        log_error "Failed to start bootstrap node"
        return 1
    fi
    
    # Wait for bootstrap node to be ready and get its ID
    log_info "Waiting for bootstrap node to initialize..."
    sleep 10
    
    local bootstrap_node_id=""
    local attempts=0
    while [[ $attempts -lt 12 ]]; do
        local health_response=$(curl -sf "http://localhost:8545/health" 2>/dev/null || echo "")
        if [[ -n "$health_response" ]]; then
            bootstrap_node_id=$(echo "$health_response" | jq -r '.node_id // ""' 2>/dev/null || echo "")
            if [[ -n "$bootstrap_node_id" && "$bootstrap_node_id" != "null" ]]; then
                log_success "Bootstrap node ID: $bootstrap_node_id"
                break
            fi
        fi
        ((attempts++))
        log_info "Waiting for bootstrap node... (attempt $attempts/12)"
        sleep 5
    done
    
    if [[ -z "$bootstrap_node_id" ]]; then
        log_error "Failed to get bootstrap node ID"
        return 1
    fi
    
    # Update configs with bootstrap node ID
    update_configs_with_bootstrap_id "$bootstrap_node_id"
    
    # Start other nodes
    for i in {2..3}; do
        if ! start_node "$i"; then
            log_error "Failed to start node $i"
            return 1
        fi
        sleep 3
    done
    
    echo
    log_success "🎉 P2P Network started successfully!"
    echo
    log_info "Network endpoints:"
    log_info "  • Bootstrap Node 1: RPC http://localhost:8545, P2P :9001"
    log_info "  • Node 2: RPC http://localhost:8546, P2P :9002"
    log_info "  • Node 3: RPC http://localhost:8547, P2P :9003"
    echo
    log_info "🔧 Management commands:"
    log_info "  • Check status: bash scripts/check-p2p-status-updated.sh"
    log_info "  • Stop network: $0 stop"
    log_info "  • View logs: tail -f logs/node*.err"
}

# Stop the network
stop_network() {
    log_p2p "🛑 Stopping Agent Chain P2P Network"
    
    for i in {1..3}; do
        local pid_file="$PROJECT_ROOT/logs/node$i.pid"
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                rm -f "$pid_file"
                log_info "Stopped node $i (PID: $pid)"
            fi
        fi
    done
    
    log_success "P2P Network stopped"
}

# Show network status
show_status() {
    log_p2p "📊 P2P Network Status"
    
    for i in {1..3}; do
        local rpc_port=$((8544 + i))
        local health_response=$(curl -sf "http://localhost:$rpc_port/health" 2>/dev/null || echo "")
        
        if [[ -n "$health_response" ]]; then
            local node_id=$(echo "$health_response" | jq -r '.node_id // "unknown"' 2>/dev/null || echo "unknown")
            local peers=$(echo "$health_response" | jq -r '.peers // 0' 2>/dev/null || echo "0")
            local height=$(echo "$health_response" | jq -r '.height // 0' 2>/dev/null || echo "0")
            
            log_success "Node $i: Online (Peers: $peers, Height: $height)"
            log_info "  Node ID: ${node_id:0:30}..."
        else
            log_warning "Node $i: Offline"
        fi
    done
}

# Main function
main() {
    case "$COMMAND" in
        start)
            start_network
            ;;
        stop)
            stop_network
            ;;
        status)
            show_status
            ;;
        restart)
            stop_network
            sleep 2
            start_network
            ;;
        *)
            echo "Usage: $0 {start|stop|status|restart}"
            echo
            echo "Commands:"
            echo "  start     Start the P2P network"
            echo "  stop      Stop all nodes"
            echo "  status    Show network status"
            echo "  restart   Restart the network"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
