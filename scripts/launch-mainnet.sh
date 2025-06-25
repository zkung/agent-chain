#!/bin/bash

# Agent Chain Mainnet Launch Script
# Version: 1.0.0
# Purpose: Launch mainnet with genesis block

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GENESIS_TIME="${GENESIS_TIME:-2024-12-19T18:00:00Z}"
CHAIN_ID="agent-chain-mainnet"

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
log_launch() { echo -e "${PURPLE}[LAUNCH]${NC} $1"; }
log_network() { echo -e "${CYAN}[NETWORK]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_launch "Checking prerequisites..."
    
    # Check if genesis is initialized
    if [[ ! -f "$PROJECT_ROOT/genesis/genesis.json" ]]; then
        log_error "Genesis not initialized. Run initialize-genesis.sh first."
        exit 1
    fi
    
    # Check if node binaries exist
    if [[ ! -f "$PROJECT_ROOT/node" ]] && [[ ! -f "$PROJECT_ROOT/node.exe" ]]; then
        log_error "Node binary not found. Build the project first."
        exit 1
    fi
    
    # Check if validator keys exist
    for i in {1..3}; do
        if [[ ! -f "$PROJECT_ROOT/genesis/validators/validator$i/priv_validator_key.json" ]]; then
            log_error "Validator $i keys not found"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Wait for genesis time
wait_for_genesis_time() {
    log_launch "Checking genesis time..."
    
    local genesis_timestamp=$(date -d "$GENESIS_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$GENESIS_TIME" +%s 2>/dev/null)
    local current_timestamp=$(date +%s)
    
    if [[ $current_timestamp -lt $genesis_timestamp ]]; then
        local wait_seconds=$((genesis_timestamp - current_timestamp))
        log_launch "Waiting for genesis time: $GENESIS_TIME"
        log_info "Time remaining: $wait_seconds seconds"
        
        # Countdown for the last 60 seconds
        if [[ $wait_seconds -le 60 ]]; then
            for ((i=wait_seconds; i>0; i--)); do
                echo -ne "\r${PURPLE}[COUNTDOWN]${NC} Genesis in: $i seconds   "
                sleep 1
            done
            echo
        else
            sleep $((wait_seconds - 60))
            for ((i=60; i>0; i--)); do
                echo -ne "\r${PURPLE}[COUNTDOWN]${NC} Genesis in: $i seconds   "
                sleep 1
            done
            echo
        fi
    fi
    
    log_success "Genesis time reached!"
}

# Start validator node
start_validator_node() {
    local validator_id="$1"
    local node_dir="$PROJECT_ROOT/genesis/nodes/validator$validator_id"
    local data_dir="$node_dir/data"
    local config_file="$node_dir/config.toml"
    
    log_network "Starting validator $validator_id..."
    
    # Determine node binary
    local node_binary="$PROJECT_ROOT/node"
    if [[ -f "$PROJECT_ROOT/node.exe" ]]; then
        node_binary="$PROJECT_ROOT/node.exe"
    fi
    
    # Start node in background
    cd "$PROJECT_ROOT"
    
    local log_file="$PROJECT_ROOT/logs/validator$validator_id.log"
    mkdir -p "$(dirname "$log_file")"
    
    # Start the node
    nohup "$node_binary" start \
        --home "$data_dir" \
        --config "$config_file" \
        --genesis "$data_dir/genesis.json" \
        --p2p-port $((9000 + validator_id)) \
        --rpc-port $((8544 + validator_id)) \
        --validator \
        --chain-id "$CHAIN_ID" \
        > "$log_file" 2>&1 &
    
    local node_pid=$!
    echo "$node_pid" > "$PROJECT_ROOT/logs/validator$validator_id.pid"
    
    log_success "Validator $validator_id started (PID: $node_pid)"
    
    # Wait a moment for startup
    sleep 3
    
    # Check if process is still running
    if ! kill -0 "$node_pid" 2>/dev/null; then
        log_error "Validator $validator_id failed to start"
        return 1
    fi
    
    return 0
}

# Check node health
check_node_health() {
    local validator_id="$1"
    local rpc_port=$((8544 + validator_id))
    
    log_network "Checking validator $validator_id health..."
    
    # Try to connect to RPC endpoint
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -sf "http://localhost:$rpc_port/health" >/dev/null 2>&1; then
            log_success "Validator $validator_id is healthy"
            return 0
        fi
        
        ((attempt++))
        sleep 2
    done
    
    log_error "Validator $validator_id health check failed"
    return 1
}

# Wait for network consensus
wait_for_consensus() {
    log_network "Waiting for network consensus..."
    
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local consensus_count=0
        
        # Check each validator
        for i in {1..3}; do
            local rpc_port=$((8544 + i))
            if curl -sf "http://localhost:$rpc_port/status" >/dev/null 2>&1; then
                ((consensus_count++))
            fi
        done
        
        if [[ $consensus_count -ge 2 ]]; then
            log_success "Network consensus achieved ($consensus_count/3 validators)"
            return 0
        fi
        
        log_info "Consensus progress: $consensus_count/3 validators"
        ((attempt++))
        sleep 5
    done
    
    log_error "Failed to achieve network consensus"
    return 1
}

# Verify genesis block
verify_genesis_block() {
    log_network "Verifying genesis block..."
    
    # Get genesis block from first validator
    local genesis_block=$(curl -sf "http://localhost:8545/block?height=0" 2>/dev/null || echo "")
    
    if [[ -z "$genesis_block" ]]; then
        log_error "Failed to retrieve genesis block"
        return 1
    fi
    
    # Verify block height is 0
    local block_height=$(echo "$genesis_block" | jq -r '.result.block.header.height // "unknown"')
    if [[ "$block_height" != "0" ]]; then
        log_error "Invalid genesis block height: $block_height"
        return 1
    fi
    
    # Verify chain ID
    local block_chain_id=$(echo "$genesis_block" | jq -r '.result.block.header.chain_id // "unknown"')
    if [[ "$block_chain_id" != "$CHAIN_ID" ]]; then
        log_error "Invalid chain ID: $block_chain_id"
        return 1
    fi
    
    log_success "Genesis block verified successfully"
    return 0
}

# Monitor initial block production
monitor_block_production() {
    log_network "Monitoring initial block production..."
    
    local initial_height=0
    local max_wait=120  # 2 minutes
    local elapsed=0
    
    while [[ $elapsed -lt $max_wait ]]; do
        local current_height=$(curl -sf "http://localhost:8545/status" 2>/dev/null | jq -r '.result.sync_info.latest_block_height // "0"')
        
        if [[ "$current_height" != "0" ]] && [[ "$current_height" != "null" ]]; then
            log_success "Block production started! Current height: $current_height"
            return 0
        fi
        
        echo -ne "\r${CYAN}[MONITOR]${NC} Waiting for first block... (${elapsed}s/${max_wait}s)"
        sleep 5
        ((elapsed += 5))
    done
    
    echo
    log_error "Block production did not start within timeout"
    return 1
}

# Display network status
display_network_status() {
    log_launch "Displaying network status..."
    
    echo
    echo "🌟 AGENT CHAIN MAINNET STATUS"
    echo "=" * 50
    
    # Network info
    echo "📋 Network Information:"
    echo "  • Chain ID: $CHAIN_ID"
    echo "  • Genesis Time: $GENESIS_TIME"
    echo "  • Launch Time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo
    
    # Validator status
    echo "🏛️ Validator Status:"
    for i in {1..3}; do
        local rpc_port=$((8544 + i))
        local status="❌ Offline"
        local height="N/A"
        
        if curl -sf "http://localhost:$rpc_port/health" >/dev/null 2>&1; then
            status="✅ Online"
            height=$(curl -sf "http://localhost:$rpc_port/status" 2>/dev/null | jq -r '.result.sync_info.latest_block_height // "0"')
        fi
        
        echo "  • Validator $i: $status (Height: $height, Port: $rpc_port)"
    done
    echo
    
    # Network endpoints
    echo "🔗 Network Endpoints:"
    echo "  • RPC: http://localhost:8545"
    echo "  • Validator 2: http://localhost:8546"
    echo "  • Validator 3: http://localhost:8547"
    echo
    
    # Management commands
    echo "🔧 Management Commands:"
    echo "  • Check status: curl http://localhost:8545/status"
    echo "  • View logs: tail -f logs/validator1.log"
    echo "  • Stop network: pkill -f 'node start'"
    echo
}

# Main launch function
main() {
    log_launch "🚀 Starting Agent Chain Mainnet Launch"
    echo "=" * 60
    log_info "Genesis Time: $GENESIS_TIME"
    log_info "Chain ID: $CHAIN_ID"
    echo
    
    # Pre-launch checks
    check_prerequisites
    
    # Wait for genesis time
    wait_for_genesis_time
    
    # Launch sequence
    log_launch "🌟 MAINNET LAUNCH SEQUENCE INITIATED"
    echo
    
    # Start validators in sequence
    for i in {1..3}; do
        if ! start_validator_node "$i"; then
            log_error "Failed to start validator $i"
            exit 1
        fi
        sleep 2
    done
    
    # Health checks
    for i in {1..3}; do
        if ! check_node_health "$i"; then
            log_error "Validator $i health check failed"
            exit 1
        fi
    done
    
    # Wait for consensus
    if ! wait_for_consensus; then
        log_error "Failed to achieve consensus"
        exit 1
    fi
    
    # Verify genesis block
    if ! verify_genesis_block; then
        log_error "Genesis block verification failed"
        exit 1
    fi
    
    # Monitor block production
    if ! monitor_block_production; then
        log_error "Block production monitoring failed"
        exit 1
    fi
    
    # Success!
    echo
    log_success "🎉 AGENT CHAIN MAINNET LAUNCHED SUCCESSFULLY!"
    echo
    
    # Display status
    display_network_status
    
    log_launch "🌟 Mainnet is now live and producing blocks!"
    log_info "🎯 Network is ready for transactions and operations"
}

# Handle script interruption
trap 'log_error "Mainnet launch interrupted"; exit 1' INT TERM

# Run main function
main "$@"
