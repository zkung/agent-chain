#!/bin/bash

# Agent Chain P2P Network Startup Script
# Starts multiple nodes with automatic peer discovery

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NODE_BINARY="$PROJECT_ROOT/node"

# Default configuration
NUM_NODES=3
BASE_P2P_PORT=9001
BASE_RPC_PORT=8545

# Parse command and options
COMMAND="${1:-start}"
shift || true

# Parse remaining arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --nodes)
            NUM_NODES="$2"
            shift 2
            ;;
        --p2p-port)
            BASE_P2P_PORT="$2"
            shift 2
            ;;
        --rpc-port)
            BASE_RPC_PORT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 {start|stop|status|restart|clean} [OPTIONS]"
            echo "Options:"
            echo "  --nodes NUM       Number of nodes to start (default: 3)"
            echo "  --p2p-port PORT   Base P2P port (default: 9001)"
            echo "  --rpc-port PORT   Base RPC port (default: 8545)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build project if needed
build_project() {
    log_info "Checking Agent Chain binaries..."
    
    cd "$PROJECT_ROOT"
    
    if [[ ! -f "$NODE_BINARY" ]]; then
        log_info "Building node binary..."
        go build -o node ./cmd/node
    fi
    
    if [[ ! -f "$PROJECT_ROOT/wallet" ]]; then
        log_info "Building wallet binary..."
        go build -o wallet ./cmd/wallet
    fi
    
    log_success "Binaries ready"
}

# Start a node
start_node() {
    local node_id="$1"
    local is_bootstrap="$2"
    local bootstrap_node_id="$3"
    local p2p_port=$((BASE_P2P_PORT + node_id))
    local rpc_port=$((BASE_RPC_PORT + node_id))
    local data_dir="$PROJECT_ROOT/data/node-$node_id"

    # Create data directory
    mkdir -p "$data_dir"

    # Create node config with proper YAML format
    if [[ "$is_bootstrap" == "true" ]]; then
        cat > "$data_dir/config.yaml" << EOF
data_dir: "$data_dir"
p2p:
  port: $p2p_port
  is_bootstrap: true
  enable_discovery: true
rpc:
  port: $rpc_port
validator:
  enabled: true
EOF
    else
        # For non-bootstrap nodes, include bootstrap node address
        local bootstrap_addr="/ip4/127.0.0.1/tcp/$BASE_P2P_PORT/p2p/$bootstrap_node_id"
        cat > "$data_dir/config.yaml" << EOF
data_dir: "$data_dir"
p2p:
  port: $p2p_port
  is_bootstrap: false
  enable_discovery: true
  boot_nodes:
    - "$bootstrap_addr"
rpc:
  port: $rpc_port
validator:
  enabled: true
EOF
    fi

    # Start node
    local log_file="$data_dir/node.log"
    local err_file="$data_dir/node.err"

    log_p2p "Starting node $node_id (P2P:$p2p_port, RPC:$rpc_port, Bootstrap:$is_bootstrap)"
    nohup go run "$PROJECT_ROOT/cmd/node/main.go" --config "$data_dir/config.yaml" > "$log_file" 2> "$err_file" &

    local node_pid=$!
    echo "$node_pid" > "$data_dir/node.pid"

    # Wait for node to start
    sleep 5

    # Check if node is running
    if ! kill -0 "$node_pid" 2>/dev/null; then
        log_error "Node $node_id failed to start"
        echo "=== Log file ==="
        cat "$log_file" 2>/dev/null || echo "No log file"
        echo "=== Error file ==="
        cat "$err_file" 2>/dev/null || echo "No error file"
        return 1
    fi

    # Wait a bit more and check health
    sleep 3
    local health_check=$(curl -sf "http://localhost:$rpc_port/health" 2>/dev/null || echo "failed")
    if [[ "$health_check" == "failed" ]]; then
        log_warning "Node $node_id health check failed, but process is running"
    else
        log_success "Node $node_id started and healthy (PID: $node_pid)"
    fi

    return 0
}

# Check if node is running
check_node() {
    local node_id="$1"
    local data_dir="$PROJECT_ROOT/data/node-$node_id"
    local pid_file="$data_dir/node.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Stop a node
stop_node() {
    local node_id="$1"
    local data_dir="$PROJECT_ROOT/data/node-$node_id"
    local pid_file="$data_dir/node.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$pid_file"
            log_info "Stopped node $node_id (PID: $pid)"
        fi
    fi
}

# Start P2P network
start_network() {
    log_p2p "🚀 Starting Agent Chain P2P Network"
    echo "=" * 50
    log_info "Configuration:"
    log_info "  • Number of nodes: $NUM_NODES"
    log_info "  • P2P ports: $BASE_P2P_PORT-$((BASE_P2P_PORT + NUM_NODES - 1))"
    log_info "  • RPC ports: $BASE_RPC_PORT-$((BASE_RPC_PORT + NUM_NODES - 1))"
    echo

    # Build project
    build_project

    # Create data directory
    mkdir -p "$PROJECT_ROOT/data"

    # Start bootstrap node first
    if ! start_node 0 true ""; then
        log_error "Failed to start bootstrap node"
        return 1
    fi

    # Wait for bootstrap node to be ready and get its node ID
    log_info "Waiting for bootstrap node to initialize..."
    sleep 10

    local bootstrap_node_id=""
    local attempts=0
    while [[ $attempts -lt 12 ]]; do
        local health_response=$(curl -sf "http://localhost:$BASE_RPC_PORT/health" 2>/dev/null || echo "")
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

    # Start other nodes with bootstrap node ID
    for i in $(seq 1 $((NUM_NODES - 1))); do
        if ! start_node "$i" false "$bootstrap_node_id"; then
            log_error "Failed to start node $i"
            return 1
        fi
        sleep 3
    done

    echo
    log_success "🎉 P2P Network started successfully!"
    echo
    log_info "Network endpoints:"
    for i in $(seq 0 $((NUM_NODES - 1))); do
        local rpc_port=$((BASE_RPC_PORT + i))
        local p2p_port=$((BASE_P2P_PORT + i))
        local node_type="Node"
        if [[ $i -eq 0 ]]; then
            node_type="Bootstrap"
        fi
        log_info "  • $node_type $i: RPC http://localhost:$rpc_port, P2P :$p2p_port"
    done
    echo
    log_info "🔧 Management commands:"
    log_info "  • Check status: $0 status"
    log_info "  • Stop network: $0 stop"
    log_info "  • View logs: tail -f data/node-0/node.log"
    log_info "  • Test wallet: ./wallet height --rpc http://localhost:$BASE_RPC_PORT"
}

# Show network status
show_status() {
    log_p2p "📊 Agent Chain P2P Network Status"
    echo "=" * 50

    local active_nodes=0
    local total_peers=0

    for i in $(seq 0 $((NUM_NODES - 1))); do
        local rpc_port=$((BASE_RPC_PORT + i))
        local p2p_port=$((BASE_P2P_PORT + i))

        if check_node "$i"; then
            # Try to get more info from RPC
            local status="🟢 Running"
            local height="N/A"
            local peers="N/A"
            local node_id="N/A"

            local health_response=$(curl -sf "http://localhost:$rpc_port/health" 2>/dev/null || echo "")
            if [[ -n "$health_response" ]]; then
                height=$(echo "$health_response" | jq -r '.height // "N/A"' 2>/dev/null || echo "N/A")
                peers=$(echo "$health_response" | jq -r '.peers // "N/A"' 2>/dev/null || echo "N/A")
                node_id=$(echo "$health_response" | jq -r '.node_id // "N/A"' 2>/dev/null || echo "N/A")

                # Add to total peer count
                if [[ "$peers" != "N/A" && "$peers" =~ ^[0-9]+$ ]]; then
                    total_peers=$((total_peers + peers))
                fi
            fi

            local node_type="Node"
            if [[ $i -eq 0 ]]; then
                node_type="Bootstrap"
            fi

            log_info "$node_type $i: $status"
            log_info "  • Node ID: ${node_id:0:30}..."
            log_info "  • Height: $height, Peers: $peers"
            log_info "  • RPC: http://localhost:$rpc_port, P2P: $p2p_port"
            echo
            ((active_nodes++))
        else
            log_warning "Node $i: 🔴 Stopped (RPC: $rpc_port, P2P: $p2p_port)"
        fi
    done

    echo "=" * 50
    if [[ $active_nodes -gt 0 ]]; then
        log_success "Network status: $active_nodes/$NUM_NODES nodes active"
        log_info "Total P2P connections: $total_peers"

        if [[ $total_peers -gt 0 ]]; then
            log_success "🎉 P2P discovery is working!"
        else
            log_warning "⚠️ No P2P connections detected"
        fi
    else
        log_error "Network status: All nodes offline"
    fi
}

# Stop network
stop_network() {
    log_p2p "🛑 Stopping Agent Chain P2P Network"
    
    for i in $(seq 0 $((NUM_NODES - 1))); do
        stop_node "$i"
    done
    
    log_success "P2P Network stopped"
}

# Clean network data
clean_network() {
    log_p2p "🧹 Cleaning Agent Chain P2P Network data"
    
    # Stop all nodes first
    stop_network
    
    # Remove data directory
    if [[ -d "$PROJECT_ROOT/data" ]]; then
        rm -rf "$PROJECT_ROOT/data"
        log_success "Network data cleaned"
    else
        log_info "No data to clean"
    fi
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
        clean)
            clean_network
            ;;
        *)
            echo "Usage: $0 {start|stop|status|restart|clean} [OPTIONS]"
            echo
            echo "Commands:"
            echo "  start     Start the P2P network (default)"
            echo "  stop      Stop all nodes"
            echo "  status    Show network status"
            echo "  restart   Restart the network"
            echo "  clean     Stop and clean all data"
            echo
            echo "Options (for start command):"
            echo "  --nodes NUM       Number of nodes (default: 3)"
            echo "  --p2p-port PORT   Base P2P port (default: 9001)"
            echo "  --rpc-port PORT   Base RPC port (default: 8545)"
            echo
            echo "Examples:"
            echo "  $0 start --nodes 5"
            echo "  $0 status"
            echo "  $0 stop"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
