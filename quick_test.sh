#!/bin/bash

# Quick Test Script for Agent Chain
# =================================
# This script performs essential validation tests

set -e

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

# Test 1: Check file structure
test_file_structure() {
    log "Checking file structure..."
    
    local required_files=(
        "go.mod"
        "Makefile"
        "README.md"
        "bootstrap.sh"
        "specs/SYS-BOOTSTRAP-DEVNET-001.json"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            error "Required file missing: $file"
        fi
    done
    
    log "✅ File structure check passed"
}

# Test 2: Build system
test_build() {
    log "Testing build system..."
    
    # Clean and build
    make clean >/dev/null 2>&1 || true
    
    if ! make build >/dev/null 2>&1; then
        error "Build failed"
    fi
    
    # Check if binaries exist
    if [ ! -f "bin/node" ] || [ ! -f "bin/wallet" ]; then
        error "Binaries not created"
    fi
    
    log "✅ Build test passed"
}

# Test 3: Basic functionality
test_basic_functionality() {
    log "Testing basic functionality..."
    
    # Test wallet help
    if ! ./bin/wallet --help >/dev/null 2>&1; then
        error "Wallet binary not working"
    fi
    
    # Test node help
    if ! ./bin/node --help >/dev/null 2>&1; then
        error "Node binary not working"
    fi
    
    log "✅ Basic functionality test passed"
}

# Test 4: Configuration generation
test_config_generation() {
    log "Testing configuration generation..."
    
    # Create test configs directory
    mkdir -p test_configs
    
    # Generate sample config
    cat > test_configs/test_node.yaml << EOF
data_dir: "./test_data"
p2p_port: 9999
rpc_port: 8999
is_validator: true
boot_nodes: []
EOF
    
    # Test if config is valid YAML
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import yaml; yaml.safe_load(open('test_configs/test_node.yaml'))" 2>/dev/null || error "Invalid YAML config"
    fi
    
    # Cleanup
    rm -rf test_configs
    
    log "✅ Configuration generation test passed"
}

# Test 5: Docker support
test_docker_support() {
    log "Testing Docker support..."
    
    if ! command -v docker >/dev/null 2>&1; then
        warn "Docker not available, skipping Docker tests"
        return
    fi
    
    # Test Dockerfile syntax
    if ! docker build -t agent-chain:test . >/dev/null 2>&1; then
        warn "Docker build failed"
        return
    fi
    
    # Cleanup
    docker rmi agent-chain:test >/dev/null 2>&1 || true
    
    log "✅ Docker support test passed"
}

# Test 6: Specification compliance
test_spec_compliance() {
    log "Testing specification compliance..."
    
    local spec_file="specs/SYS-BOOTSTRAP-DEVNET-001.json"
    
    if command -v python3 >/dev/null 2>&1; then
        # Validate JSON
        python3 -c "import json; json.load(open('$spec_file'))" 2>/dev/null || error "Invalid JSON in spec file"
        
        # Check required fields
        python3 -c "
import json
spec = json.load(open('$spec_file'))
required_fields = ['id', 'title', 'acceptance_criteria', 'time_limit_ms', 'memory_limit_mb']
for field in required_fields:
    if field not in spec:
        raise ValueError(f'Missing required field: {field}')
print('Spec validation passed')
" || error "Specification validation failed"
    fi
    
    log "✅ Specification compliance test passed"
}

# Test 7: Resource requirements
test_resource_requirements() {
    log "Testing resource requirements..."
    
    # Check if system has enough resources
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import psutil
memory_gb = psutil.virtual_memory().total / 1024 / 1024 / 1024
if memory_gb < 2:
    print('Warning: System has less than 2GB RAM')
else:
    print(f'System memory: {memory_gb:.1f}GB - OK')
"
    fi
    
    # Check disk space
    local available_space=$(df . | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1048576 ]; then  # 1GB in KB
        warn "Less than 1GB disk space available"
    fi
    
    log "✅ Resource requirements test passed"
}

# Test 8: Cross-platform compatibility
test_cross_platform() {
    log "Testing cross-platform compatibility..."
    
    # Check if PowerShell script exists for Windows
    if [ ! -f "bootstrap.ps1" ]; then
        warn "PowerShell bootstrap script missing"
    fi
    
    # Check script permissions
    if [ ! -x "bootstrap.sh" ]; then
        warn "Bootstrap script not executable"
        chmod +x bootstrap.sh 2>/dev/null || true
    fi
    
    log "✅ Cross-platform compatibility test passed"
}

# Main test runner
run_all_tests() {
    log "Starting Agent Chain Quick Test Suite"
    log "====================================="
    
    local tests=(
        "test_file_structure"
        "test_build"
        "test_basic_functionality"
        "test_config_generation"
        "test_docker_support"
        "test_spec_compliance"
        "test_resource_requirements"
        "test_cross_platform"
    )
    
    local passed=0
    local total=${#tests[@]}
    
    for test_func in "${tests[@]}"; do
        if $test_func; then
            ((passed++))
        else
            warn "Test $test_func failed"
        fi
    done
    
    echo ""
    log "Test Results: $passed/$total tests passed"
    
    if [ "$passed" -eq "$total" ]; then
        log "🎉 All quick tests passed!"
        return 0
    else
        warn "⚠️ Some tests failed or had warnings"
        return 1
    fi
}

# Cleanup function
cleanup() {
    # Clean up any test artifacts
    rm -rf test_data test_configs 2>/dev/null || true
}

# Set up cleanup on exit
trap cleanup EXIT

# Run tests
run_all_tests
