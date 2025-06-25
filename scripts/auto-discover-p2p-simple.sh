#!/bin/bash

# Agent Chain P2P Auto-Discovery Script (Simplified for Windows)
# Automatically discovers P2P nodes and updates configuration files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default configuration
CONFIG_PATH="configs"
SCAN_PORT_START=8545
SCAN_PORT_END=8550
TARGET_NODE=""
DRY_RUN=false

# Logging functions
log_info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1"; }
log_p2p() { echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] [P2P]${NC} $1"; }

# Parse JSON without jq (simple extraction)
extract_json_value() {
    local json="$1"
    local key="$2"
    
    # Simple regex-based JSON extraction
    if [[ "$json" =~ \"$key\":\"?([^,}\"]+)\"? ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target-node)
                TARGET_NODE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help
show_help() {
    echo -e "${CYAN}Agent Chain P2P Auto-Discovery Tool (Simplified)${NC}"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --target-node <name>     Update specific node config (e.g., 'node2')"
    echo "  --dry-run               Show what would be changed without making changes"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0                              # Auto-discover and update all configs"
    echo "  $0 --target-node node2          # Update only node2 config"
    echo "  $0 --dry-run                    # Preview changes without applying"
}

# Discover active P2P nodes
discover_p2p_nodes() {
    log_p2p "🔍 Scanning for active P2P nodes..."
    
    local discovered_nodes=()
    
    for port in $(seq $SCAN_PORT_START $SCAN_PORT_END); do
        local response=$(curl -sf --connect-timeout 3 "http://localhost:$port/health" 2>/dev/null || echo "")
        
        if [[ -n "$response" ]]; then
            local node_id=$(extract_json_value "$response" "node_id")
            local status=$(extract_json_value "$response" "status")
            local peers=$(extract_json_value "$response" "peers")
            local height=$(extract_json_value "$response" "height")
            
            if [[ -n "$node_id" && "$status" == "ok" ]]; then
                # Calculate P2P port based on RPC port mapping
                local p2p_port
                case $port in
                    8545) p2p_port=9001 ;;
                    8546) p2p_port=9002 ;;
                    8547) p2p_port=9003 ;;
                    *) p2p_port=$((port + 456)) ;;
                esac
                
                local is_bootstrap="false"
                if [[ "$peers" -gt 0 || "$port" -eq 8545 ]]; then
                    is_bootstrap="true"
                fi
                
                local multi_addr="/ip4/127.0.0.1/tcp/$p2p_port/p2p/$node_id"
                
                # Store node info (using | as delimiter)
                discovered_nodes+=("$port|$p2p_port|$node_id|$height|$peers|$status|$is_bootstrap|$multi_addr")
                
                local node_type="Node"
                if [[ "$is_bootstrap" == "true" ]]; then
                    node_type="Bootstrap"
                fi
                
                log_success "✅ Found $node_type node: Port $port, ID: ${node_id:0:20}..., Peers: $peers"
            fi
        fi
    done
    
    if [[ ${#discovered_nodes[@]} -eq 0 ]]; then
        log_error "❌ No active P2P nodes found in port range $SCAN_PORT_START-$SCAN_PORT_END"
        return 1
    fi
    
    log_p2p "🎉 Discovered ${#discovered_nodes[@]} active P2P nodes"
    printf '%s\n' "${discovered_nodes[@]}"
}

# Get bootstrap nodes
get_bootstrap_nodes() {
    local all_nodes=("$@")
    local bootstrap_nodes=()
    
    for node in "${all_nodes[@]}"; do
        IFS='|' read -r rpc_port p2p_port node_id height peers status is_bootstrap multi_addr <<< "$node"
        
        if [[ "$is_bootstrap" == "true" ]]; then
            bootstrap_nodes+=("$node")
        fi
    done
    
    # If no bootstrap nodes found, use the first node
    if [[ ${#bootstrap_nodes[@]} -eq 0 && ${#all_nodes[@]} -gt 0 ]]; then
        bootstrap_nodes=("${all_nodes[0]}")
    fi
    
    log_p2p "🚀 Identified ${#bootstrap_nodes[@]} bootstrap nodes"
    printf '%s\n' "${bootstrap_nodes[@]}"
}

# Update configuration file
update_config_file() {
    local config_file="$1"
    shift
    local bootstrap_nodes=("$@")
    
    log_p2p "📝 Updating configuration: $config_file"
    
    if [[ ! -f "$config_file" ]]; then
        log_warning "⚠️ Config file not found: $config_file"
        return 1
    fi
    
    # Extract current node info from config
    local data_dir=$(grep -E '^data_dir:' "$config_file" | sed 's/data_dir: *"\?\([^"]*\)"\?/\1/' || echo "data/node")
    local rpc_port=$(grep -A 10 '^rpc:' "$config_file" | grep -E '^ *port:' | head -1 | sed 's/.*port: *\([0-9]*\).*/\1/' || echo "8546")
    local p2p_port=$(grep -A 10 '^p2p:' "$config_file" | grep -E '^ *port:' | head -1 | sed 's/.*port: *\([0-9]*\).*/\1/' || echo "9002")
    
    # Filter out self from bootstrap nodes
    local filtered_bootstrap=()
    for node in "${bootstrap_nodes[@]}"; do
        IFS='|' read -r node_rpc_port node_p2p_port node_id height peers status is_bootstrap multi_addr <<< "$node"
        
        if [[ "$node_rpc_port" != "$rpc_port" ]]; then
            filtered_bootstrap+=("$node")
        fi
    done
    
    if [[ ${#filtered_bootstrap[@]} -eq 0 ]]; then
        log_warning "⚠️ No suitable bootstrap nodes found (excluding self)"
        return 1
    fi
    
    # Create boot_nodes list
    local boot_nodes_list=""
    for node in "${filtered_bootstrap[@]}"; do
        IFS='|' read -r node_rpc_port node_p2p_port node_id height peers status is_bootstrap multi_addr <<< "$node"
        boot_nodes_list+="    - \"$multi_addr\"\n"
    done
    
    # Create new configuration
    local new_config="data_dir: \"$data_dir\"
p2p:
  port: $p2p_port
  is_bootstrap: false
  enable_discovery: true
  boot_nodes:
$(echo -e "$boot_nodes_list")rpc:
  port: $rpc_port
validator:
  enabled: true"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🔍 DRY RUN - Would update $config_file with:"
        echo -e "${CYAN}$new_config${NC}"
        return 0
    fi
    
    # Backup original config
    local backup_file="$config_file.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$config_file" "$backup_file"
    log_info "💾 Backup created: $backup_file"
    
    # Write new config
    echo "$new_config" > "$config_file"
    log_success "✅ Configuration updated successfully"
    
    return 0
}

# Get configuration files to update
get_config_files() {
    local config_files=()
    
    if [[ -n "$TARGET_NODE" ]]; then
        local config_file="$CONFIG_PATH/$TARGET_NODE.yaml"
        if [[ -f "$config_file" ]]; then
            config_files=("$config_file")
        else
            log_error "❌ Target config file not found: $config_file"
            return 1
        fi
    else
        # Find all node config files
        for file in "$CONFIG_PATH"/node*.yaml; do
            if [[ -f "$file" ]]; then
                config_files+=("$file")
            fi
        done
        
        if [[ ${#config_files[@]} -eq 0 ]]; then
            log_error "❌ No node configuration files found in: $CONFIG_PATH"
            return 1
        fi
    fi
    
    printf '%s\n' "${config_files[@]}"
}

# Main execution
main() {
    log_p2p "🌐 Agent Chain P2P Auto-Discovery Tool (Simplified)"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "🔍 Running in DRY RUN mode - no changes will be made"
    fi
    
    # Discover P2P nodes
    local discovered_nodes
    if ! discovered_nodes=($(discover_p2p_nodes)); then
        exit 1
    fi
    
    # Get bootstrap nodes
    local bootstrap_nodes
    bootstrap_nodes=($(get_bootstrap_nodes "${discovered_nodes[@]}"))
    
    # Display discovered nodes
    log_p2p "📊 Discovered Nodes:"
    for node in "${discovered_nodes[@]}"; do
        IFS='|' read -r rpc_port p2p_port node_id height peers status is_bootstrap multi_addr <<< "$node"
        local node_type="Node"
        if [[ "$is_bootstrap" == "true" ]]; then
            node_type="Bootstrap"
        fi
        echo -e "  • $node_type - RPC:$rpc_port, P2P:$p2p_port, Peers:$peers"
        echo -e "    ID: ${node_id:0:40}..."
    done
    
    log_p2p "🚀 Bootstrap Nodes:"
    for node in "${bootstrap_nodes[@]}"; do
        IFS='|' read -r rpc_port p2p_port node_id height peers status is_bootstrap multi_addr <<< "$node"
        echo -e "${GREEN}  • $multi_addr${NC}"
    done
    
    # Get configuration files to update
    local config_files
    if ! config_files=($(get_config_files)); then
        exit 1
    fi
    
    log_p2p "📝 Updating Configuration Files:"
    local update_count=0
    
    for config_file in "${config_files[@]}"; do
        local file_name=$(basename "$config_file")
        echo -e "${YELLOW}  • $file_name${NC}"
        
        if update_config_file "$config_file" "${bootstrap_nodes[@]}"; then
            ((update_count++))
        fi
    done
    
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
    log_info "📈 Summary: Updated $update_count/${#config_files[@]} configuration files"
    
    log_p2p "🎉 P2P Auto-Discovery completed!"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "💡 Check network status with: bash scripts/check-p2p-status-updated.sh"
    fi
}

# Parse arguments and run main
parse_args "$@"
main
