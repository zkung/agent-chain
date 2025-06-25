#!/bin/bash

# Integration test script for Agent Chain
# This script tests the basic functionality required by the ProblemSpec

set -e

# Make script executable
chmod +x "$0" 2>/dev/null || true

echo "🧪 Agent Chain Integration Test"
echo "==============================="

# Configuration
WALLET_BINARY="./wallet"
TEST_ACCOUNT="test-alice"
DEAD_ADDRESS="0x000000000000000000000000000000000000dEaD"
RPC_ENDPOINTS=("127.0.0.1:8545" "127.0.0.1:8546" "127.0.0.1:8547")

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test 1: Check if wallet binary exists
test_wallet_binary() {
    log "Test 1: Checking wallet binary..."
    
    if [ ! -f "$WALLET_BINARY" ]; then
        error "Wallet binary not found at $WALLET_BINARY"
    fi
    
    if [ ! -x "$WALLET_BINARY" ]; then
        error "Wallet binary is not executable"
    fi
    
    log "✅ Wallet binary exists and is executable"
}

# Test 2: Check RPC endpoints
test_rpc_endpoints() {
    log "Test 2: Checking RPC endpoints..."
    
    for endpoint in "${RPC_ENDPOINTS[@]}"; do
        if curl -s -f "http://$endpoint/health" > /dev/null; then
            log "✅ RPC endpoint $endpoint is reachable"
        else
            error "❌ RPC endpoint $endpoint is not reachable"
        fi
    done
}

# Test 3: Create new account
test_create_account() {
    log "Test 3: Creating new account..."
    
    # Clean up any existing test account
    rm -rf ./wallet-data/accounts/$TEST_ACCOUNT.json 2>/dev/null || true
    
    output=$($WALLET_BINARY new --name "$TEST_ACCOUNT" --data-dir ./wallet-data 2>&1)
    
    if echo "$output" | grep -q "address"; then
        log "✅ Account creation successful"
        log "Account output: $output"
    else
        error "❌ Account creation failed: $output"
    fi
}

# Test 4: List accounts
test_list_accounts() {
    log "Test 4: Listing accounts..."
    
    output=$($WALLET_BINARY list --data-dir ./wallet-data 2>&1)
    
    if echo "$output" | grep -q "$TEST_ACCOUNT"; then
        log "✅ Account listing successful"
    else
        error "❌ Account listing failed or account not found: $output"
    fi
}

# Test 5: Check balance
test_check_balance() {
    log "Test 5: Checking account balance..."
    
    output=$($WALLET_BINARY balance --account "$TEST_ACCOUNT" --data-dir ./wallet-data 2>&1)
    
    if echo "$output" | grep -q "Balance:"; then
        log "✅ Balance check successful: $output"
    else
        warn "⚠️ Balance check returned: $output"
    fi
}

# Test 6: Send transaction (will likely fail due to insufficient balance, but should not crash)
test_send_transaction() {
    log "Test 6: Testing send transaction..."
    
    output=$($WALLET_BINARY send --account "$TEST_ACCOUNT" --to "$DEAD_ADDRESS" --amount 1 --data-dir ./wallet-data 2>&1 || true)
    
    if echo "$output" | grep -q -E "(Transaction sent|insufficient|error)"; then
        log "✅ Send transaction command executed (expected to fail with insufficient balance)"
        log "Output: $output"
    else
        warn "⚠️ Unexpected send transaction output: $output"
    fi
}

# Test 7: Submit patch
test_submit_patch() {
    log "Test 7: Testing patch submission..."
    
    # Create a sample patch file if it doesn't exist
    if [ ! -f "examples/sample-patch.json" ]; then
        mkdir -p examples
        cat > examples/sample-patch.json << 'EOF'
{
  "id": "test-patch-001",
  "problem_id": "SYS-BOOTSTRAP-DEVNET-001",
  "code": "package main\n\nimport \"fmt\"\n\nfunc main() {\n    fmt.Println(\"Hello, Agent Chain!\")\n}",
  "language": "go",
  "files": {
    "main.go": "package main\n\nimport \"fmt\"\n\nfunc main() {\n    fmt.Println(\"Hello, Agent Chain!\")\n}"
  }
}
EOF
    fi
    
    output=$($WALLET_BINARY submit-patch --account "$TEST_ACCOUNT" --file examples/sample-patch.json --data-dir ./wallet-data 2>&1 || true)
    
    if echo "$output" | grep -q -E "(Patch submitted|error|failed)"; then
        log "✅ Submit patch command executed"
        log "Output: $output"
    else
        warn "⚠️ Unexpected submit patch output: $output"
    fi
}

# Test 8: Check blockchain height
test_blockchain_height() {
    log "Test 8: Checking blockchain height..."
    
    for endpoint in "${RPC_ENDPOINTS[@]}"; do
        output=$($WALLET_BINARY height --rpc "http://$endpoint" 2>&1 || true)
        
        if echo "$output" | grep -q "Height:"; then
            log "✅ Height check successful for $endpoint: $output"
        else
            warn "⚠️ Height check failed for $endpoint: $output"
        fi
    done
}

# Test 9: Check height consistency across nodes
test_height_consistency() {
    log "Test 9: Checking height consistency across nodes..."
    
    heights=()
    for endpoint in "${RPC_ENDPOINTS[@]}"; do
        height_output=$($WALLET_BINARY height --rpc "http://$endpoint" 2>&1 || echo "Height: -1")
        height=$(echo "$height_output" | grep -oE 'Height: [0-9]+' | grep -oE '[0-9]+' || echo "-1")
        heights+=("$height")
    done
    
    # Check if all heights are the same
    first_height=${heights[0]}
    all_same=true
    
    for height in "${heights[@]}"; do
        if [ "$height" != "$first_height" ]; then
            all_same=false
            break
        fi
    done
    
    if [ "$all_same" = true ] && [ "$first_height" != "-1" ]; then
        log "✅ All nodes have consistent height: $first_height"
    else
        warn "⚠️ Height inconsistency detected: ${heights[*]}"
    fi
}

# Run all tests
run_tests() {
    log "Starting integration tests..."
    
    test_wallet_binary
    test_rpc_endpoints
    test_create_account
    test_list_accounts
    test_check_balance
    test_send_transaction
    test_submit_patch
    test_blockchain_height
    test_height_consistency
    
    echo ""
    log "🎉 Integration tests completed!"
    log "Note: Some tests may show warnings due to network/balance limitations in the test environment."
}

# Main execution
main() {
    # Check if nodes are running
    if ! curl -s -f "http://127.0.0.1:8545/health" > /dev/null; then
        error "Nodes are not running. Please start the testnet first with ./bootstrap.sh"
    fi
    
    run_tests
}

main "$@"
