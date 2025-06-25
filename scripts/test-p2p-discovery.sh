#!/bin/bash

# Agent Chain P2P Discovery Test Script
# Tests the automatic peer discovery mechanism

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
WALLET_BINARY="$PROJECT_ROOT/wallet"

# Test configuration
NUM_NODES=5
BASE_P2P_PORT=9001
BASE_RPC_PORT=8545
TEST_DURATION=60

# Node PIDs
declare -a NODE_PIDS=()

# Cleanup function
cleanup() {
    log_info "Cleaning up test nodes..."
    
    for pid in "${NODE_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_info "Stopped node with PID $pid"
        fi
    done
    
    # Clean up data directories
    rm -rf "$PROJECT_ROOT"/test-node-*
    
    log_success "Cleanup completed"
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Build project if needed
build_project() {
    log_info "Building Agent Chain..."
    
    cd "$PROJECT_ROOT"
    
    if [[ ! -f "$NODE_BINARY" ]] || [[ ! -f "$WALLET_BINARY" ]]; then
        log_info "Building binaries..."
        go build -o node ./cmd/node
        go build -o wallet ./cmd/wallet
    fi
    
    log_success "Project built successfully"
}

# Start a test node
start_test_node() {
    local node_id="$1"
    local is_bootstrap="$2"
    local bootstrap_node_id="$3"
    local p2p_port=$((BASE_P2P_PORT + node_id))
    local rpc_port=$((BASE_RPC_PORT + node_id))
    local data_dir="$PROJECT_ROOT/test-node-$node_id"

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

    log_p2p "Starting node $node_id on ports P2P:$p2p_port RPC:$rpc_port (Bootstrap:$is_bootstrap)"
    go run "$PROJECT_ROOT/cmd/node/main.go" --config "$data_dir/config.yaml" > "$log_file" 2> "$err_file" &

    local node_pid=$!
    NODE_PIDS+=("$node_pid")

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

    log_success "Node $node_id started successfully (PID: $node_pid)"
    return 0
}

# Check node connectivity
check_node_connectivity() {
    local node_id="$1"
    local rpc_port=$((BASE_RPC_PORT + node_id))
    
    # Try to connect to RPC endpoint
    if curl -sf "http://localhost:$rpc_port/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get node peer count
get_peer_count() {
    local node_id="$1"
    local rpc_port=$((BASE_RPC_PORT + node_id))
    
    # Get peer count from RPC
    local response=$(curl -sf "http://localhost:$rpc_port/peers" 2>/dev/null || echo "0")
    echo "$response" | jq -r '.peer_count // 0' 2>/dev/null || echo "0"
}

# Monitor network formation
monitor_network() {
    log_p2p "Monitoring P2P network formation..."
    
    local start_time=$(date +%s)
    local max_wait=120
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $max_wait ]]; then
            log_warning "Network formation timeout after ${max_wait}s"
            break
        fi
        
        # Check all nodes
        local active_nodes=0
        local total_connections=0
        
        echo -ne "\r${PURPLE}[P2P]${NC} Network status (${elapsed}s): "
        
        for i in $(seq 0 $((NUM_NODES - 1))); do
            if check_node_connectivity "$i"; then
                local peer_count=$(get_peer_count "$i")
                echo -ne "Node$i:$peer_count "
                ((active_nodes++))
                total_connections=$((total_connections + peer_count))
            else
                echo -ne "Node$i:X "
            fi
        done
        
        # Check if network is well connected
        local avg_connections=0
        if [[ $active_nodes -gt 0 ]]; then
            avg_connections=$((total_connections / active_nodes))
        fi
        
        if [[ $active_nodes -ge 3 ]] && [[ $avg_connections -ge 2 ]]; then
            echo
            log_success "P2P network formed successfully!"
            log_info "Active nodes: $active_nodes/$NUM_NODES"
            log_info "Average connections per node: $avg_connections"
            return 0
        fi
        
        sleep 5
    done
    
    echo
    return 1
}

# Test peer discovery
test_peer_discovery() {
    log_p2p "Testing peer discovery mechanism..."

    # Start bootstrap node first
    start_test_node 0 true ""
    sleep 10

    # Get bootstrap node ID
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

    # Start regular nodes one by one with bootstrap node ID
    for i in $(seq 1 $((NUM_NODES - 1))); do
        start_test_node "$i" false "$bootstrap_node_id"
        sleep 3
    done

    # Monitor network formation
    if monitor_network; then
        log_success "Peer discovery test passed!"
        return 0
    else
        log_error "Peer discovery test failed!"
        return 1
    fi
}

# Test network resilience
test_network_resilience() {
    log_p2p "Testing network resilience..."
    
    # Stop bootstrap node
    local bootstrap_pid="${NODE_PIDS[0]}"
    if kill -0 "$bootstrap_pid" 2>/dev/null; then
        kill "$bootstrap_pid"
        log_info "Stopped bootstrap node"
        
        # Remove from PID array
        NODE_PIDS=("${NODE_PIDS[@]:1}")
    fi
    
    # Wait and check if network remains connected
    sleep 10
    
    local active_nodes=0
    for i in $(seq 1 $((NUM_NODES - 1))); do
        if check_node_connectivity "$i"; then
            ((active_nodes++))
        fi
    done
    
    if [[ $active_nodes -ge 2 ]]; then
        log_success "Network resilience test passed! $active_nodes nodes still active"
        return 0
    else
        log_error "Network resilience test failed! Only $active_nodes nodes active"
        return 1
    fi
}

# Generate test report
generate_report() {
    log_info "Generating P2P discovery test report..."
    
    local report_file="$PROJECT_ROOT/p2p_discovery_test_report.json"
    
    cat > "$report_file" << EOF
{
  "test_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "test_duration": $TEST_DURATION,
  "num_nodes": $NUM_NODES,
  "results": {
    "peer_discovery": "$discovery_result",
    "network_resilience": "$resilience_result"
  },
  "node_stats": [
EOF
    
    # Add node statistics
    for i in $(seq 0 $((NUM_NODES - 1))); do
        local status="offline"
        local peer_count=0
        
        if check_node_connectivity "$i"; then
            status="online"
            peer_count=$(get_peer_count "$i")
        fi
        
        cat >> "$report_file" << EOF
    {
      "node_id": $i,
      "status": "$status",
      "peer_count": $peer_count,
      "p2p_port": $((BASE_P2P_PORT + i)),
      "rpc_port": $((BASE_RPC_PORT + i))
    }$([ $i -lt $((NUM_NODES - 1)) ] && echo "," || echo "")
EOF
    done
    
    cat >> "$report_file" << EOF
  ]
}
EOF
    
    log_success "Test report saved: $report_file"
}

# Main test function
main() {
    log_p2p "🌐 Starting Agent Chain P2P Discovery Test"
    echo "=" * 60
    log_info "Test configuration:"
    log_info "  • Number of nodes: $NUM_NODES"
    log_info "  • P2P ports: $BASE_P2P_PORT-$((BASE_P2P_PORT + NUM_NODES - 1))"
    log_info "  • RPC ports: $BASE_RPC_PORT-$((BASE_RPC_PORT + NUM_NODES - 1))"
    log_info "  • Test duration: ${TEST_DURATION}s"
    echo
    
    # Build project
    build_project
    
    # Test peer discovery
    local discovery_result="failed"
    if test_peer_discovery; then
        discovery_result="passed"
    fi
    
    # Test network resilience
    local resilience_result="failed"
    if test_network_resilience; then
        resilience_result="passed"
    fi
    
    # Wait for test duration
    log_info "Running network for ${TEST_DURATION}s to observe behavior..."
    sleep "$TEST_DURATION"
    
    # Generate report
    generate_report
    
    # Final results
    echo
    log_p2p "🎯 P2P Discovery Test Results:"
    echo "=" * 40
    log_info "Peer Discovery: $discovery_result"
    log_info "Network Resilience: $resilience_result"
    
    if [[ "$discovery_result" == "passed" ]] && [[ "$resilience_result" == "passed" ]]; then
        log_success "🎉 All P2P discovery tests passed!"
        return 0
    else
        log_error "❌ Some P2P discovery tests failed!"
        return 1
    fi
}

# Run main function
main "$@"
