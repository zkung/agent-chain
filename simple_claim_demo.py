#!/usr/bin/env python3
"""
Simple Reward Claiming Demo
===========================
A simplified demonstration of the reward claiming process.
"""

import subprocess
import json
import os

def run_command(cmd):
    """Run a command and return success status."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, 
                              encoding='utf-8', errors='ignore')
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def main():
    print("🏆 Agent Chain Reward Claiming Demo")
    print("=" * 50)
    
    # 1. Check claimable rewards
    print("1. Checking claimable rewards...")
    success, stdout, stderr = run_command(["./wallet.exe", "claim", "--check"])
    if success:
        print(f"✅ {stdout.strip()}")
    else:
        print(f"❌ Failed: {stderr}")
    
    print()
    
    # 2. Claim 200 tokens
    print("2. Claiming 200 tokens...")
    success, stdout, stderr = run_command(["./wallet.exe", "claim", "--account", "alice", "--amount", "200"])
    if success:
        print("✅ Claim successful!")
        print("Transaction details shown in wallet output")
    else:
        print(f"❌ Failed: {stderr}")
    
    print()
    
    # 3. Check remaining claimable
    print("3. Checking remaining claimable...")
    success, stdout, stderr = run_command(["./wallet.exe", "claim", "--check"])
    if success:
        print(f"✅ {stdout.strip()}")
    else:
        print(f"❌ Failed: {stderr}")
    
    print()
    
    # 4. Claim all remaining
    print("4. Claiming all remaining rewards...")
    success, stdout, stderr = run_command(["./wallet.exe", "claim", "--account", "alice"])
    if success:
        print("✅ All rewards claimed!")
    else:
        print(f"❌ Failed: {stderr}")
    
    print()
    print("🎉 Reward claiming demo completed!")

if __name__ == "__main__":
    main()
