#!/bin/sh

# Simple monitoring script for Agent Chain nodes

echo "🔍 Agent Chain Network Monitor"
echo "=============================="

while true; do
    echo ""
    echo "$(date): Checking node status..."
    
    # Check each node
    for i in 1 2 3; do
        port=$((8544 + i))
        node_name="node$i"
        
        if wget -q --spider --timeout=5 "http://$node_name:$port/health" 2>/dev/null; then
            echo "✅ Node $i (port $port): Healthy"
        else
            echo "❌ Node $i (port $port): Unhealthy"
        fi
    done
    
    # Sleep for 30 seconds
    sleep 30
done
