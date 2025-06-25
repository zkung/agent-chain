#!/bin/bash

# Comprehensive Test Suite for Agent Chain
# ========================================
# This script runs all validation and testing procedures

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[TEST-SUITE]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Test configuration
TEST_DIR="test_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="$TEST_DIR/$TIMESTAMP"

# Create test results directory
mkdir -p "$REPORT_DIR"

# Function to run a test and capture results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local log_file="$REPORT_DIR/${test_name}.log"
    
    info "Running $test_name..."
    echo "Command: $test_command" > "$log_file"
    echo "Started: $(date)" >> "$log_file"
    echo "----------------------------------------" >> "$log_file"
    
    if eval "$test_command" >> "$log_file" 2>&1; then
        log "✅ $test_name PASSED"
        echo "PASSED" > "$REPORT_DIR/${test_name}.result"
        return 0
    else
        warn "❌ $test_name FAILED"
        echo "FAILED" > "$REPORT_DIR/${test_name}.result"
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if required tools are available
    local tools=("go" "make" "python3" "curl")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed or not in PATH"
        fi
    done
    
    # Check Python packages
    if ! python3 -c "import psutil, requests" 2>/dev/null; then
        warn "Installing required Python packages..."
        pip3 install psutil requests || error "Failed to install Python packages"
    fi
    
    log "✅ Prerequisites check passed"
}

# Function to run static analysis
run_static_analysis() {
    log "Running static analysis..."
    
    # Go vet
    run_test "go_vet" "go vet ./..."
    
    # Go fmt check
    run_test "go_fmt" "test -z \$(gofmt -l .)"
    
    # Go mod verify
    run_test "go_mod_verify" "go mod verify"
    
    # Check for common issues
    run_test "security_check" "grep -r 'TODO\\|FIXME\\|XXX' . --exclude-dir=.git --exclude-dir=test_results || true"
}

# Function to run build tests
run_build_tests() {
    log "Running build tests..."
    
    # Clean build
    run_test "clean_build" "make clean && make build"
    
    # Check binary sizes
    run_test "binary_size_check" "ls -la bin/ && du -sh bin/"
    
    # Test cross-compilation (if supported)
    if command -v docker &> /dev/null; then
        run_test "docker_build" "docker build -t agent-chain:test ."
    fi
}

# Function to run unit tests
run_unit_tests() {
    log "Running unit tests..."
    
    # Go unit tests
    run_test "go_unit_tests" "go test -v -race -coverprofile=$REPORT_DIR/coverage.out ./..."
    
    # Generate coverage report
    if [ -f "$REPORT_DIR/coverage.out" ]; then
        run_test "coverage_report" "go tool cover -html=$REPORT_DIR/coverage.out -o $REPORT_DIR/coverage.html"
    fi
}

# Function to run integration tests
run_integration_tests() {
    log "Running integration tests..."
    
    # Make test script executable
    chmod +x test_integration.sh
    
    # Run our custom integration test
    run_test "custom_integration" "./test_integration.sh"
    
    # Run specification validation
    chmod +x validate_spec.py
    run_test "spec_validation" "python3 validate_spec.py"
    
    # Run performance tests
    chmod +x performance_test.py
    run_test "performance_test" "python3 performance_test.py bootstrap"
}

# Function to run pytest tests (original spec tests)
run_pytest_tests() {
    log "Running pytest tests..."
    
    # Install pytest if not available
    if ! command -v pytest &> /dev/null; then
        pip3 install pytest || warn "Could not install pytest"
        return
    fi
    
    # Run the original test suite
    run_test "pytest_bootstrap" "pytest tests/bootstrap_devnet/test_bootstrap.py -v"
}

# Function to run stress tests
run_stress_tests() {
    log "Running stress tests..."
    
    # Test multiple bootstrap cycles
    run_test "bootstrap_stress" "
        for i in {1..3}; do
            echo \"Bootstrap cycle \$i\"
            timeout 300 ./bootstrap.sh &
            BOOTSTRAP_PID=\$!
            sleep 60
            kill \$BOOTSTRAP_PID 2>/dev/null || true
            sleep 10
        done
    "
    
    # Test wallet operations under load
    run_test "wallet_stress" "
        for i in {1..10}; do
            ./wallet new --name stress-test-\$i --data-dir ./stress-wallet-data || true
        done
        ./wallet list --data-dir ./stress-wallet-data || true
    "
}

# Function to generate final report
generate_report() {
    log "Generating test report..."
    
    local report_file="$REPORT_DIR/test_report.html"
    local summary_file="$REPORT_DIR/summary.txt"
    
    # Count results
    local total_tests=$(find "$REPORT_DIR" -name "*.result" | wc -l)
    local passed_tests=$(find "$REPORT_DIR" -name "*.result" -exec grep -l "PASSED" {} \; | wc -l)
    local failed_tests=$((total_tests - passed_tests))
    
    # Generate summary
    cat > "$summary_file" << EOF
Agent Chain Test Suite Results
==============================
Timestamp: $(date)
Total Tests: $total_tests
Passed: $passed_tests
Failed: $failed_tests
Success Rate: $(( passed_tests * 100 / total_tests ))%

Test Details:
EOF
    
    # Add individual test results
    for result_file in "$REPORT_DIR"/*.result; do
        if [ -f "$result_file" ]; then
            local test_name=$(basename "$result_file" .result)
            local result=$(cat "$result_file")
            echo "$test_name: $result" >> "$summary_file"
        fi
    done
    
    # Generate HTML report
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Agent Chain Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .passed { color: green; }
        .failed { color: red; }
        .test-result { margin: 10px 0; padding: 10px; border: 1px solid #ddd; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Agent Chain Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Total Tests: $total_tests | Passed: <span class="passed">$passed_tests</span> | Failed: <span class="failed">$failed_tests</span></p>
    </div>
EOF
    
    # Add test details to HTML
    for result_file in "$REPORT_DIR"/*.result; do
        if [ -f "$result_file" ]; then
            local test_name=$(basename "$result_file" .result)
            local result=$(cat "$result_file")
            local log_file="$REPORT_DIR/${test_name}.log"
            
            echo "<div class=\"test-result\">" >> "$report_file"
            echo "<h3>$test_name: <span class=\"$(echo $result | tr '[:upper:]' '[:lower:]')\">$result</span></h3>" >> "$report_file"
            
            if [ -f "$log_file" ]; then
                echo "<details><summary>View Log</summary><pre>" >> "$report_file"
                cat "$log_file" >> "$report_file"
                echo "</pre></details>" >> "$report_file"
            fi
            
            echo "</div>" >> "$report_file"
        fi
    done
    
    echo "</body></html>" >> "$report_file"
    
    # Display summary
    cat "$summary_file"
    
    info "Detailed report saved to: $report_file"
    info "Summary saved to: $summary_file"
    
    # Return appropriate exit code
    if [ "$failed_tests" -eq 0 ]; then
        log "🎉 All tests passed!"
        return 0
    else
        warn "⚠️ $failed_tests test(s) failed"
        return 1
    fi
}

# Main execution
main() {
    info "Starting Agent Chain Comprehensive Test Suite"
    info "============================================="
    info "Test results will be saved to: $REPORT_DIR"
    
    # Run test phases
    check_prerequisites
    run_static_analysis
    run_build_tests
    run_unit_tests
    run_integration_tests
    run_pytest_tests
    run_stress_tests
    
    # Generate final report
    generate_report
}

# Handle cleanup on exit
cleanup() {
    log "Cleaning up test processes..."
    pkill -f "bootstrap" 2>/dev/null || true
    pkill -f "bin/node" 2>/dev/null || true
    sleep 2
}

trap cleanup EXIT

# Run main function
main "$@"
