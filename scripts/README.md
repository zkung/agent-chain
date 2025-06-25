# Agent Chain P2P Scripts

This directory contains updated shell scripts for managing the Agent Chain P2P network with proper peer discovery functionality.

## 🚀 Quick Start

### Start P2P Network
```bash
# Using the new bootstrap script (recommended)
bash scripts/bootstrap-p2p-network.sh start

# Or using the updated start script
bash scripts/start-p2p-network.sh start
```

### Check Network Status
```bash
# Quick status check
bash scripts/check-p2p-status-updated.sh

# Detailed status with the original script
bash scripts/start-p2p-network.sh status

# Real-time monitoring
bash scripts/check-p2p-status-updated.sh monitor
```

### Test P2P Discovery
```bash
# Test discovery mechanism
bash scripts/check-p2p-status-updated.sh test

# Full discovery test suite
bash scripts/test-p2p-discovery.sh
```

### Stop Network
```bash
bash scripts/bootstrap-p2p-network.sh stop
# or
bash scripts/start-p2p-network.sh stop
```

## 📁 Script Overview

### Core Scripts

1. **`bootstrap-p2p-network.sh`** ⭐ **RECOMMENDED**
   - Simplified, verified P2P network startup
   - Uses the exact configuration format that works
   - Automatically handles bootstrap node ID discovery
   - Creates proper multiaddr format for peer connections

2. **`start-p2p-network.sh`** (Updated)
   - Enhanced version of the original startup script
   - Supports proper YAML configuration format
   - Includes bootstrap node ID discovery
   - Better error handling and logging

3. **`check-p2p-status-updated.sh`** ⭐ **RECOMMENDED**
   - Modern P2P status checker
   - Real-time monitoring capabilities
   - P2P discovery testing
   - Colorized output with detailed diagnostics

### Testing Scripts

4. **`test-p2p-discovery.sh`** (Updated)
   - Comprehensive P2P discovery testing
   - Network resilience testing
   - Automated test report generation
   - Uses proper configuration format

5. **`connect-p2p.sh`**
   - Manual P2P connection utilities
   - Connectivity testing between nodes
   - Troubleshooting tools

### Legacy Scripts

6. **`check-p2p-status.sh`**
   - Original status checker (still functional)
   - Basic network overview

## 🔧 Configuration Format

The updated scripts use the correct YAML configuration format:

### Bootstrap Node (Node 1)
```yaml
data_dir: "data/node1"
p2p:
  port: 9001
  is_bootstrap: true
  enable_discovery: true
rpc:
  port: 8545
validator:
  enabled: true
```

### Regular Nodes (Node 2, 3)
```yaml
data_dir: "data/node2"
p2p:
  port: 9002
  is_bootstrap: false
  enable_discovery: true
  boot_nodes:
    - "/ip4/127.0.0.1/tcp/9001/p2p/12D3KooW..."
rpc:
  port: 8546
validator:
  enabled: true
```

## 🎯 Key Improvements

### ✅ Fixed Issues
1. **Correct multiaddr format**: Now includes `/p2p/NodeID` in bootstrap addresses
2. **Proper YAML structure**: Matches the actual node configuration parser
3. **Bootstrap node ID discovery**: Automatically retrieves and uses correct node IDs
4. **Better error handling**: More detailed error messages and troubleshooting info
5. **Real-time monitoring**: Live status updates and connection monitoring

### 🆕 New Features
1. **Automated configuration**: Scripts generate correct configs automatically
2. **P2P discovery testing**: Built-in tests for peer discovery functionality
3. **Network diagnostics**: Detailed health checks and troubleshooting
4. **Colorized output**: Better visual feedback and status indicators

## 📊 Network Topology

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Bootstrap     │────▶│     Node 2      │     │     Node 3      │
│   Node 1        │     │                 │     │                 │
│   Port: 8545    │     │   Port: 8546    │     │   Port: 8547    │
│   P2P: 9001     │◀────│   P2P: 9002     │────▶│   P2P: 9003     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## 🔍 Troubleshooting

### Common Issues

1. **No P2P connections**
   ```bash
   # Check if bootstrap node ID is correct
   curl http://localhost:8545/health | jq '.node_id'
   
   # Verify configuration files
   grep -A5 "boot_nodes:" configs/node*.yaml
   ```

2. **Nodes not starting**
   ```bash
   # Check error logs
   tail -f logs/node*.err
   
   # Verify ports are available
   netstat -an | grep -E ":(8545|8546|8547|9001|9002|9003)"
   ```

3. **Discovery not working**
   ```bash
   # Test discovery mechanism
   bash scripts/check-p2p-status-updated.sh test
   
   # Monitor in real-time
   bash scripts/check-p2p-status-updated.sh monitor
   ```

## 📝 Examples

### Start and Monitor Network
```bash
# Start network
bash scripts/bootstrap-p2p-network.sh start

# Wait a moment for initialization
sleep 10

# Check status
bash scripts/check-p2p-status-updated.sh

# Expected output:
# 🟢 Bootstrap (localhost:8545): ...
# 🟢 Node (localhost:8546): Connected Peers: 1
# 🟢 Node (localhost:8547): Connected Peers: 1
```

### Test P2P Discovery
```bash
# Run discovery test
bash scripts/check-p2p-status-updated.sh test

# Expected output:
# 🎉 P2P Discovery test PASSED!
# ✅ All active nodes are connected to peers
# ✅ Total connections: 4
```

## 🎉 Success Indicators

When P2P discovery is working correctly, you should see:

1. **All nodes healthy**: All 3 nodes respond to health checks
2. **Peer connections**: Each node shows connected peers > 0
3. **Block synchronization**: Nodes have similar block heights
4. **Unique node IDs**: Each node has a distinct libp2p peer ID

The updated scripts ensure these conditions are met automatically! 🚀
