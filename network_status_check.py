#!/usr/bin/env python3
"""
Network Status Check
===================
Simple script to check if the Agent Chain network is running properly.
"""

import subprocess
import socket
import time

def check_port(host, port, timeout=5):
    """Check if a port is open."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(timeout)
            result = s.connect_ex((host, port))
            return result == 0
    except:
        return False

def check_network_status():
    """Check the status of the Agent Chain network."""
    print("🔍 Checking Agent Chain Network Status")
    print("=" * 40)
    
    # Check RPC endpoints
    endpoints = [
        ("127.0.0.1", 8545),
        ("127.0.0.1", 8546),
        ("127.0.0.1", 8547)
    ]
    
    active_endpoints = 0
    for host, port in endpoints:
        if check_port(host, port):
            print(f"✅ {host}:{port} - Active")
            active_endpoints += 1
        else:
            print(f"❌ {host}:{port} - Inactive")
    
    # Check wallet functionality
    print("\n🔧 Testing Wallet Commands:")
    
    # Test height command
    try:
        result = subprocess.run(['./wallet.exe', 'height'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"✅ Height: {result.stdout.strip()}")
        else:
            print(f"❌ Height check failed: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ Height check error: {e}")
        return False
    
    # Test account list
    try:
        result = subprocess.run(['./wallet.exe', 'list'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✅ Account list successful")
        else:
            print(f"❌ Account list failed: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ Account list error: {e}")
        return False
    
    # Overall status
    network_healthy = active_endpoints >= 2
    print(f"\n📊 Network Status: {'✅ Healthy' if network_healthy else '❌ Unhealthy'}")
    print(f"📊 Active Endpoints: {active_endpoints}/3")
    
    return network_healthy

if __name__ == "__main__":
    success = check_network_status()
    if success:
        print("\n🎉 Network is running properly!")
        exit(0)
    else:
        print("\n⚠️ Network issues detected!")
        exit(1)
