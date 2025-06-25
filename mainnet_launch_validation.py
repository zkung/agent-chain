#!/usr/bin/env python3
"""
Mainnet Launch Validation
=========================
Final validation script before mainnet launch.
"""

import subprocess
import time
import json
import socket
from datetime import datetime

def check_port(host, port, timeout=5):
    """Check if a port is open."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(timeout)
            result = s.connect_ex((host, port))
            return result == 0
    except:
        return False

def run_command(cmd, timeout=30):
    """Run a command and return result."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, 
                              timeout=timeout, encoding='utf-8', errors='ignore')
        return result.returncode == 0, result.stdout, result.stderr
    except:
        return False, "", "Command failed"

def validate_mainnet_readiness():
    """Validate mainnet readiness."""
    print("🚀 Agent Chain Mainnet Launch Validation")
    print("=" * 50)
    
    validation_results = {}
    
    # 1. Network Infrastructure
    print("\n1️⃣ Network Infrastructure Validation")
    endpoints = [
        ("127.0.0.1", 8545),
        ("127.0.0.1", 8546),
        ("127.0.0.1", 8547)
    ]
    
    active_endpoints = 0
    for host, port in endpoints:
        if check_port(host, port):
            print(f"   ✅ {host}:{port} - Active")
            active_endpoints += 1
        else:
            print(f"   ❌ {host}:{port} - Inactive")
    
    validation_results["network_infrastructure"] = active_endpoints >= 3
    
    # 2. Core Wallet Functions
    print("\n2️⃣ Core Wallet Functions Validation")
    wallet_tests = [
        ("Height Query", ["./wallet.exe", "height"]),
        ("Account List", ["./wallet.exe", "list"]),
        ("Balance Check", ["./wallet.exe", "balance", "--account", "alice"]),
    ]
    
    wallet_success = 0
    for test_name, cmd in wallet_tests:
        success, stdout, stderr = run_command(cmd, timeout=10)
        if success:
            print(f"   ✅ {test_name}: Success")
            wallet_success += 1
        else:
            print(f"   ❌ {test_name}: Failed - {stderr[:50]}")
    
    validation_results["wallet_functions"] = wallet_success == len(wallet_tests)
    
    # 3. Security Mechanisms
    print("\n3️⃣ Security Mechanisms Validation")
    
    # Test insufficient balance protection
    success, stdout, stderr = run_command([
        "./wallet.exe", "send",
        "--account", "alice",
        "--to", "0x000000000000000000000000000000000000dEaD",
        "--amount", "999999999"
    ], timeout=10)
    
    balance_protection = not success and ("insufficient" in stderr.lower() or "balance" in stderr.lower())
    if balance_protection:
        print("   ✅ Balance Protection: Active")
    else:
        print("   ❌ Balance Protection: Failed")
    
    validation_results["security_mechanisms"] = balance_protection
    
    # 4. Staking System
    print("\n4️⃣ Staking System Validation")
    
    staking_tests = [
        ("Reward Check", ["./wallet.exe", "claim", "--check"]),
        ("Validator Stake", ["./wallet.exe", "stake", "--amount", "1000", "--role", "validator"]),
    ]
    
    staking_success = 0
    for test_name, cmd in staking_tests:
        success, stdout, stderr = run_command(cmd, timeout=15)
        if success:
            print(f"   ✅ {test_name}: Success")
            staking_success += 1
        else:
            print(f"   ❌ {test_name}: Failed - {stderr[:50]}")
    
    validation_results["staking_system"] = staking_success >= 1  # At least reward check should work
    
    # 5. Performance Metrics
    print("\n5️⃣ Performance Metrics Validation")
    
    # Test response time
    start_time = time.time()
    success, stdout, stderr = run_command(["./wallet.exe", "height"], timeout=5)
    response_time = time.time() - start_time
    
    if success and response_time < 3.0:
        print(f"   ✅ Response Time: {response_time:.2f}s (< 3s)")
        performance_ok = True
    else:
        print(f"   ❌ Response Time: {response_time:.2f}s (>= 3s)")
        performance_ok = False
    
    validation_results["performance_metrics"] = performance_ok
    
    # 6. Block Production
    print("\n6️⃣ Block Production Validation")
    
    # Get initial height
    success1, stdout1, _ = run_command(["./wallet.exe", "height"], timeout=5)
    if success1 and "Height:" in stdout1:
        height1 = int(stdout1.strip().split(":")[-1].strip())
    else:
        height1 = 0
    
    # Wait and check again
    time.sleep(15)
    success2, stdout2, _ = run_command(["./wallet.exe", "height"], timeout=5)
    if success2 and "Height:" in stdout2:
        height2 = int(stdout2.strip().split(":")[-1].strip())
    else:
        height2 = 0
    
    block_production = height2 > height1
    if block_production:
        print(f"   ✅ Block Production: Active ({height1} → {height2})")
    else:
        print(f"   ❌ Block Production: Stalled ({height1} → {height2})")
    
    validation_results["block_production"] = block_production
    
    # Final Assessment
    print("\n" + "=" * 50)
    print("🎯 MAINNET LAUNCH VALIDATION RESULTS")
    print("=" * 50)
    
    total_checks = len(validation_results)
    passed_checks = sum(validation_results.values())
    success_rate = (passed_checks / total_checks) * 100
    
    print(f"📊 Validation Summary:")
    print(f"   • Total Checks: {total_checks}")
    print(f"   • Passed: {passed_checks}")
    print(f"   • Success Rate: {success_rate:.1f}%")
    print()
    
    print("📋 Detailed Results:")
    for check, result in validation_results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        check_name = check.replace("_", " ").title()
        print(f"   {status} {check_name}")
    
    # Mainnet readiness decision
    mainnet_ready = all(validation_results.values())
    
    print(f"\n🚀 Mainnet Launch Status: {'✅ READY' if mainnet_ready else '❌ NOT READY'}")
    
    if mainnet_ready:
        print("\n🎉 MAINNET LAUNCH APPROVED!")
        print("✅ All validation checks passed")
        print("🚀 Agent Chain is ready for production deployment")
        print()
        print("📋 Launch Checklist:")
        print("   1. ✅ Network infrastructure validated")
        print("   2. ✅ Core wallet functions operational")
        print("   3. ✅ Security mechanisms active")
        print("   4. ✅ Staking system functional")
        print("   5. ✅ Performance metrics acceptable")
        print("   6. ✅ Block production active")
        print()
        print("🎯 Next Steps:")
        print("   • Deploy to production environment")
        print("   • Initialize mainnet genesis block")
        print("   • Start validator onboarding")
        print("   • Begin public network operation")
        
        # Save launch approval
        launch_approval = {
            "timestamp": datetime.now().isoformat(),
            "validation_results": validation_results,
            "success_rate": f"{success_rate:.1f}%",
            "mainnet_ready": mainnet_ready,
            "approval_status": "APPROVED",
            "next_steps": [
                "Deploy to production environment",
                "Initialize mainnet genesis block", 
                "Start validator onboarding",
                "Begin public network operation"
            ]
        }
        
        with open("mainnet_launch_approval.json", "w") as f:
            json.dump(launch_approval, f, indent=2)
        
        print("\n📝 Launch approval saved to: mainnet_launch_approval.json")
        
    else:
        print("\n⚠️ MAINNET LAUNCH DELAYED")
        print("❌ Some validation checks failed")
        print("🔧 Please address the following issues:")
        
        for check, result in validation_results.items():
            if not result:
                check_name = check.replace("_", " ").title()
                print(f"   • Fix {check_name}")
        
        print("\n🔄 Re-run validation after fixes")
    
    return mainnet_ready, validation_results

def main():
    """Main validation function."""
    try:
        ready, results = validate_mainnet_readiness()
        return 0 if ready else 1
    except Exception as e:
        print(f"\n❌ Validation failed with error: {e}")
        return 1

if __name__ == "__main__":
    exit(main())
