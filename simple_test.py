#!/usr/bin/env python3
"""
Simple Test for Agent Chain Bootstrap
====================================
This test validates the basic functionality without pytest complexity.
"""

import subprocess
import time
import socket
import os

def wait_port(host, port, timeout=60):
    """Wait for port to be available."""
    for _ in range(timeout):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(1)
                result = s.connect_ex((host, port))
                if result == 0:
                    return True
        except:
            pass
        time.sleep(1)
    return False

def test_bootstrap():
    """Test bootstrap functionality."""
    print("🧪 Starting Agent Chain Bootstrap Test")
    print("=" * 50)
    
    # Clean up existing processes
    try:
        subprocess.run(['taskkill', '/F', '/IM', 'node.exe'], 
                      capture_output=True, check=False)
        time.sleep(2)
    except:
        pass
    
    # Start bootstrap
    print("1. Starting bootstrap script...")
    proc = subprocess.Popen(['powershell', '-ExecutionPolicy', 'Bypass', 
                           '-File', 'bootstrap.ps1'], 
                          stdout=subprocess.PIPE, 
                          stderr=subprocess.STDOUT, text=True)
    
    try:
        # Wait for RPC endpoints
        print("2. Waiting for RPC endpoints...")
        endpoints = [
            ("127.0.0.1", 8545),
            ("127.0.0.1", 8546), 
            ("127.0.0.1", 8547)
        ]
        
        for host, port in endpoints:
            print(f"   Waiting for {host}:{port}...")
            if wait_port(host, port, 120):
                print(f"   ✅ {host}:{port} is up")
            else:
                print(f"   ❌ {host}:{port} failed to start")
                return False
        
        # Give nodes time to initialize
        print("3. Waiting for nodes to initialize...")
        time.sleep(10)
        
        # Test wallet commands
        print("4. Testing wallet commands...")
        
        # Create account
        print("   Creating account...")
        result = subprocess.run(['./wallet.exe', 'new', '--name', 'test'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("   ✅ Account creation successful")
            print(f"   Output: {result.stdout.strip()}")
        else:
            print(f"   ❌ Account creation failed: {result.stderr}")
            return False
        
        # Check height
        print("   Checking blockchain height...")
        result = subprocess.run(['./wallet.exe', 'height'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("   ✅ Height check successful")
            print(f"   Output: {result.stdout.strip()}")
        else:
            print(f"   ❌ Height check failed: {result.stderr}")
            return False
        
        # Test send (might fail due to balance, but should not crash)
        print("   Testing send transaction...")
        result = subprocess.run(['./wallet.exe', 'send', 
                               '--to', '0x000000000000000000000000000000000000dEaD',
                               '--amount', '1'], 
                              capture_output=True, text=True)
        print(f"   Send result: {result.stdout.strip()}")
        if result.stderr:
            print(f"   Send error: {result.stderr.strip()}")
        
        print("\n🎉 All tests completed successfully!")
        return True
        
    finally:
        # Cleanup
        print("\n5. Cleaning up...")
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
        
        # Kill node processes
        try:
            subprocess.run(['taskkill', '/F', '/IM', 'node.exe'], 
                          capture_output=True, check=False)
        except:
            pass

if __name__ == "__main__":
    success = test_bootstrap()
    if success:
        print("\n✅ TEST PASSED")
        exit(0)
    else:
        print("\n❌ TEST FAILED")
        exit(1)
