#!/bin/bash

# Agent Chain Bootstrap Script
# Starts a 3-node local testnet with CLI wallet

set -e

echo "🚀 Agent Chain Bootstrap - Starting 3-node testnet..."

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
LOGS_DIR="$SCRIPT_DIR/logs"
BIN_DIR="$SCRIPT_DIR/bin"

# Node configurations
NODE1_P2P_PORT=9001
NODE1_RPC_PORT=8545
NODE2_P2P_PORT=9002
NODE2_RPC_PORT=8546
NODE3_P2P_PORT=9003
NODE3_RPC_PORT=8547

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Cleanup function
cleanup() {
    log "Cleaning up processes..."
    pkill -f "bin/node" || true
    sleep 2
}

# Trap cleanup on exit
trap cleanup EXIT

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v go &> /dev/null; then
        error "Go is not installed. Please install Go 1.21 or later."
    fi

    GO_VERSION=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//')
    # Simple version check without bc dependency
    MAJOR=$(echo $GO_VERSION | cut -d. -f1)
    MINOR=$(echo $GO_VERSION | cut -d. -f2)
    if [ "$MAJOR" -lt 1 ] || ([ "$MAJOR" -eq 1 ] && [ "$MINOR" -lt 21 ]); then
        error "Go version $GO_VERSION is too old. Please install Go 1.21 or later."
    fi
    
    log "✅ Dependencies check passed"
}

# Build binaries
build_binaries() {
    log "Building binaries..."
    
    # Create bin directory
    mkdir -p "$BIN_DIR"
    
    # Build node
    log "Building node binary..."
    go build -o "$BIN_DIR/node" ./cmd/node
    
    # Build wallet
    log "Building wallet binary..."
    go build -o "$BIN_DIR/wallet" ./cmd/wallet
    
    # Make binaries executable
    chmod +x "$BIN_DIR/node"
    chmod +x "$BIN_DIR/wallet"
    
    # Copy wallet to current directory for tests
    cp "$BIN_DIR/wallet" ./wallet
    
    log "✅ Binaries built successfully"
}

# Create directories
create_directories() {
    log "Creating directories..."
    
    mkdir -p "$DATA_DIR"/{node1,node2,node3}
    mkdir -p "$LOGS_DIR"
    mkdir -p configs
    
    log "✅ Directories created"
}

# Generate node configurations
generate_configs() {
    log "Generating node configurations..."
    
    # Node 1 config
    cat > configs/node1.yaml << EOF
data_dir: "$DATA_DIR/node1"
p2p_port: $NODE1_P2P_PORT
rpc_port: $NODE1_RPC_PORT
is_validator: true
boot_nodes: []
EOF

    # Node 2 config
    cat > configs/node2.yaml << EOF
data_dir: "$DATA_DIR/node2"
p2p_port: $NODE2_P2P_PORT
rpc_port: $NODE2_RPC_PORT
is_validator: true
boot_nodes:
  - "/ip4/127.0.0.1/tcp/$NODE1_P2P_PORT"
EOF

    # Node 3 config
    cat > configs/node3.yaml << EOF
data_dir: "$DATA_DIR/node3"
p2p_port: $NODE3_P2P_PORT
rpc_port: $NODE3_RPC_PORT
is_validator: true
boot_nodes:
  - "/ip4/127.0.0.1/tcp/$NODE1_P2P_PORT"
  - "/ip4/127.0.0.1/tcp/$NODE2_P2P_PORT"
EOF

    log "✅ Node configurations generated"
}

# Start nodes
start_nodes() {
    log "Starting nodes..."
    
    # Start node 1
    log "Starting node 1 (P2P: $NODE1_P2P_PORT, RPC: $NODE1_RPC_PORT)..."
    "$BIN_DIR/node" --config configs/node1.yaml > "$LOGS_DIR/node1.log" 2>&1 &
    NODE1_PID=$!
    
    # Wait a bit for node 1 to start
    sleep 3
    
    # Start node 2
    log "Starting node 2 (P2P: $NODE2_P2P_PORT, RPC: $NODE2_RPC_PORT)..."
    "$BIN_DIR/node" --config configs/node2.yaml > "$LOGS_DIR/node2.log" 2>&1 &
    NODE2_PID=$!
    
    # Wait a bit for node 2 to start
    sleep 3
    
    # Start node 3
    log "Starting node 3 (P2P: $NODE3_P2P_PORT, RPC: $NODE3_RPC_PORT)..."
    "$BIN_DIR/node" --config configs/node3.yaml > "$LOGS_DIR/node3.log" 2>&1 &
    NODE3_PID=$!
    
    # Wait for nodes to fully start
    sleep 5
    
    log "✅ All nodes started"
    log "Node PIDs: $NODE1_PID, $NODE2_PID, $NODE3_PID"
}

# Check node health
check_nodes() {
    log "Checking node health..."
    
    local all_healthy=true
    
    for port in $NODE1_RPC_PORT $NODE2_RPC_PORT $NODE3_RPC_PORT; do
        if curl -s -f "http://127.0.0.1:$port/health" > /dev/null; then
            log "✅ Node on port $port is healthy"
        else
            warn "❌ Node on port $port is not responding"
            all_healthy=false
        fi
    done
    
    if [ "$all_healthy" = true ]; then
        log "✅ All nodes are healthy"
    else
        error "Some nodes are not healthy. Check logs in $LOGS_DIR/"
    fi
}

# Create sample wallet account
create_sample_account() {
    log "Creating sample wallet account..."
    
    # Create a sample account
    ./wallet new --name alice --data-dir ./wallet-data > /dev/null 2>&1 || true
    
    log "✅ Sample account 'alice' created"
    log "Use './wallet list' to see all accounts"
}

# Display status
display_status() {
    echo ""
    echo -e "${BLUE}🎉 Agent Chain Testnet is running!${NC}"
    echo ""
    echo -e "${GREEN}RPC Endpoints:${NC}"
    echo "  Node 1: http://127.0.0.1:$NODE1_RPC_PORT"
    echo "  Node 2: http://127.0.0.1:$NODE2_RPC_PORT"
    echo "  Node 3: http://127.0.0.1:$NODE3_RPC_PORT"
    echo ""
    echo -e "${GREEN}CLI Wallet Commands:${NC}"
    echo "  ./wallet new --name <name>                    # Create new account"
    echo "  ./wallet list                                 # List accounts"
    echo "  ./wallet balance --account <name>             # Check balance"
    echo "  ./wallet send --account <name> --to <addr> --amount <amount>  # Send tokens"
    echo "  ./wallet height                               # Get blockchain height"
    echo ""
    echo -e "${GREEN}Logs:${NC}"
    echo "  Node logs: $LOGS_DIR/"
    echo "  tail -f $LOGS_DIR/node1.log                   # Follow node 1 logs"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop all nodes${NC}"
}

# Wait for interrupt
wait_for_interrupt() {
    # Keep the script running until interrupted
    while true; do
        sleep 1
    done
}

# Main execution
main() {
    log "Starting Agent Chain Bootstrap..."
    
    check_dependencies
    build_binaries
    create_directories
    generate_configs
    start_nodes
    check_nodes
    create_sample_account
    display_status
    wait_for_interrupt
}

# Run main function
main "$@"
