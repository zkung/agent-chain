#!/usr/bin/env python3
"""
Agent Chain Mainnet Pre-launch Test Suite
=========================================
Comprehensive testing suite for mainnet readiness validation.
"""

import subprocess
import time
import json
import threading
import psutil
import os
from datetime import datetime, timedelta

class MainnetTestSuite:
    def __init__(self):
        self.test_results = {}
        self.start_time = datetime.now()
        self.monitoring_active = False
        
    def log(self, message, level="INFO"):
        """Log test messages with timestamp."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
    
    def run_command(self, cmd, timeout=30):
        """Run a command with timeout and return result."""
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, 
                                  timeout=timeout, encoding='utf-8', errors='ignore')
            return result.returncode == 0, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, "", "Command timed out"
        except Exception as e:
            return False, "", str(e)
    
    def test_basic_functionality(self):
        """Test 1: Basic functionality verification."""
        self.log("🧪 Starting Basic Functionality Tests", "TEST")
        
        tests = [
            ("Network startup", ["python", "simple_test.py"]),
            ("Wallet list", ["./wallet.exe", "list"]),
            ("Blockchain height", ["./wallet.exe", "height"]),
            ("Account balance", ["./wallet.exe", "balance", "--account", "alice"]),
        ]
        
        results = {}
        for test_name, cmd in tests:
            self.log(f"  Testing: {test_name}")
            success, stdout, stderr = self.run_command(cmd)
            results[test_name] = {
                "success": success,
                "output": stdout[:200] if stdout else "",
                "error": stderr[:200] if stderr else ""
            }
            status = "✅ PASS" if success else "❌ FAIL"
            self.log(f"    {status}: {test_name}")
        
        self.test_results["basic_functionality"] = results
        return all(r["success"] for r in results.values())
    
    def test_transaction_processing(self):
        """Test 2: Transaction processing under load."""
        self.log("🧪 Starting Transaction Processing Tests", "TEST")
        
        # Test multiple transactions
        results = {}
        
        # Test 1: Single transaction
        self.log("  Testing: Single transaction")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "send", 
            "--to", "0x000000000000000000000000000000000000dEaD",
            "--amount", "1"
        ])
        results["single_transaction"] = success
        
        # Test 2: Multiple rapid transactions
        self.log("  Testing: Multiple rapid transactions")
        rapid_success = 0
        for i in range(5):
            success, _, _ = self.run_command([
                "./wallet.exe", "send",
                "--to", "0x000000000000000000000000000000000000dEaD", 
                "--amount", "1"
            ], timeout=10)
            if success:
                rapid_success += 1
            time.sleep(1)
        
        results["rapid_transactions"] = rapid_success >= 3
        
        # Test 3: PatchSet submission
        self.log("  Testing: PatchSet submission")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "submit-patch",
            "--spec", "TEST-001",
            "--code", "agent-chain-patchset.tar.gz",
            "--gas", "50000"
        ])
        results["patchset_submission"] = success
        
        self.test_results["transaction_processing"] = results
        return all(results.values())
    
    def test_staking_system(self):
        """Test 3: Staking system functionality."""
        self.log("🧪 Starting Staking System Tests", "TEST")
        
        results = {}
        
        # Test validator staking
        self.log("  Testing: Validator staking")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "stake",
            "--amount", "1000",
            "--role", "validator"
        ])
        results["validator_staking"] = success
        
        # Test delegator staking
        self.log("  Testing: Delegator staking")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "stake",
            "--amount", "500", 
            "--role", "delegator"
        ])
        results["delegator_staking"] = success
        
        # Test reward claiming
        self.log("  Testing: Reward claiming")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "claim", "--check"
        ])
        results["reward_check"] = success
        
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "claim", "--amount", "100"
        ])
        results["reward_claim"] = success
        
        # Test unstaking
        self.log("  Testing: Unstaking")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "stake", "--unstake"
        ])
        results["unstaking"] = success
        
        self.test_results["staking_system"] = results
        return all(results.values())
    
    def test_network_resilience(self):
        """Test 4: Network resilience and recovery."""
        self.log("🧪 Starting Network Resilience Tests", "TEST")
        
        results = {}
        
        # Test 1: Network connectivity
        self.log("  Testing: Network connectivity")
        endpoints = [
            "http://127.0.0.1:8545/health",
            "http://127.0.0.1:8546/health", 
            "http://127.0.0.1:8547/health"
        ]
        
        connectivity_success = 0
        for endpoint in endpoints:
            success, _, _ = self.run_command(["curl", "-s", endpoint])
            if success:
                connectivity_success += 1
        
        results["network_connectivity"] = connectivity_success >= 2
        
        # Test 2: Block height consistency
        self.log("  Testing: Block height consistency")
        heights = []
        for i in range(3):
            success, stdout, stderr = self.run_command(["./wallet.exe", "height"])
            if success and "Height:" in stdout:
                height = stdout.strip().split(":")[-1].strip()
                heights.append(height)
            time.sleep(2)
        
        results["height_consistency"] = len(set(heights)) <= 2  # Allow 1 block difference
        
        # Test 3: Continuous operation
        self.log("  Testing: Continuous operation (30 seconds)")
        start_time = time.time()
        continuous_success = 0
        while time.time() - start_time < 30:
            success, _, _ = self.run_command(["./wallet.exe", "height"], timeout=5)
            if success:
                continuous_success += 1
            time.sleep(3)
        
        results["continuous_operation"] = continuous_success >= 8
        
        self.test_results["network_resilience"] = results
        return all(results.values())
    
    def test_performance_metrics(self):
        """Test 5: Performance and resource usage."""
        self.log("🧪 Starting Performance Tests", "TEST")
        
        results = {}
        
        # Monitor system resources
        process_info = []
        for proc in psutil.process_iter(['pid', 'name', 'memory_info', 'cpu_percent']):
            try:
                if 'node' in proc.info['name'].lower() or 'wallet' in proc.info['name'].lower():
                    process_info.append(proc.info)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        # Memory usage test
        total_memory = sum(proc['memory_info'].rss for proc in process_info) / 1024 / 1024  # MB
        results["memory_usage"] = total_memory < 1024  # Less than 1GB
        self.log(f"  Memory usage: {total_memory:.1f} MB")
        
        # Response time test
        start_time = time.time()
        success, _, _ = self.run_command(["./wallet.exe", "height"])
        response_time = time.time() - start_time
        results["response_time"] = response_time < 3.0  # Less than 3 seconds
        self.log(f"  Response time: {response_time:.2f} seconds")
        
        # Disk usage test
        if os.path.exists("data"):
            disk_usage = sum(
                os.path.getsize(os.path.join(dirpath, filename))
                for dirpath, dirnames, filenames in os.walk("data")
                for filename in filenames
            ) / 1024 / 1024  # MB
            results["disk_usage"] = disk_usage < 500  # Less than 500MB
            self.log(f"  Disk usage: {disk_usage:.1f} MB")
        else:
            results["disk_usage"] = True
        
        self.test_results["performance_metrics"] = results
        return all(results.values())
    
    def test_security_features(self):
        """Test 6: Security features validation."""
        self.log("🧪 Starting Security Tests", "TEST")
        
        results = {}
        
        # Test 1: Invalid transaction rejection
        self.log("  Testing: Invalid transaction rejection")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "send",
            "--to", "invalid_address",
            "--amount", "1"
        ])
        results["invalid_tx_rejection"] = not success  # Should fail
        
        # Test 2: Signature verification
        self.log("  Testing: Account creation and signing")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "new", "--name", "test_security"
        ])
        results["account_creation"] = success
        
        # Test 3: Balance protection
        self.log("  Testing: Insufficient balance protection")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "send",
            "--to", "0x000000000000000000000000000000000000dEaD",
            "--amount", "999999999"
        ])
        results["balance_protection"] = not success  # Should fail
        
        self.test_results["security_features"] = results
        return all(results.values())
    
    def generate_test_report(self):
        """Generate comprehensive test report."""
        self.log("📊 Generating Test Report", "REPORT")
        
        total_tests = sum(len(category) for category in self.test_results.values())
        passed_tests = sum(
            sum(1 for result in category.values() if 
                (isinstance(result, bool) and result) or 
                (isinstance(result, dict) and result.get("success", False)))
            for category in self.test_results.values()
        )
        
        report = {
            "test_summary": {
                "start_time": self.start_time.isoformat(),
                "end_time": datetime.now().isoformat(),
                "total_tests": total_tests,
                "passed_tests": passed_tests,
                "success_rate": f"{(passed_tests/total_tests*100):.1f}%" if total_tests > 0 else "0%",
                "overall_status": "PASS" if passed_tests == total_tests else "FAIL"
            },
            "detailed_results": self.test_results,
            "mainnet_readiness": {
                "basic_functionality": all(
                    r.get("success", r) if isinstance(r, dict) else r 
                    for r in self.test_results.get("basic_functionality", {}).values()
                ),
                "transaction_processing": all(self.test_results.get("transaction_processing", {}).values()),
                "staking_system": all(self.test_results.get("staking_system", {}).values()),
                "network_resilience": all(self.test_results.get("network_resilience", {}).values()),
                "performance_metrics": all(self.test_results.get("performance_metrics", {}).values()),
                "security_features": all(self.test_results.get("security_features", {}).values())
            }
        }
        
        # Save report to file
        with open("mainnet_test_report.json", "w") as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        print("\n" + "="*60)
        print("🎯 MAINNET READINESS TEST REPORT")
        print("="*60)
        print(f"📊 Test Summary:")
        print(f"  • Total Tests: {total_tests}")
        print(f"  • Passed: {passed_tests}")
        print(f"  • Success Rate: {report['test_summary']['success_rate']}")
        print(f"  • Overall Status: {report['test_summary']['overall_status']}")
        print()
        
        print("📋 Category Results:")
        for category, status in report["mainnet_readiness"].items():
            status_icon = "✅" if status else "❌"
            print(f"  {status_icon} {category.replace('_', ' ').title()}")
        
        mainnet_ready = all(report["mainnet_readiness"].values())
        print(f"\n🚀 Mainnet Ready: {'YES' if mainnet_ready else 'NO'}")
        
        return report
    
    def run_full_test_suite(self):
        """Run the complete test suite."""
        self.log("🚀 Starting Agent Chain Mainnet Test Suite", "START")
        
        test_functions = [
            ("Basic Functionality", self.test_basic_functionality),
            ("Transaction Processing", self.test_transaction_processing),
            ("Staking System", self.test_staking_system),
            ("Network Resilience", self.test_network_resilience),
            ("Performance Metrics", self.test_performance_metrics),
            ("Security Features", self.test_security_features)
        ]
        
        overall_success = True
        
        for test_name, test_func in test_functions:
            self.log(f"🧪 Running {test_name} Tests")
            try:
                success = test_func()
                status = "✅ PASS" if success else "❌ FAIL"
                self.log(f"  {status}: {test_name}")
                if not success:
                    overall_success = False
            except Exception as e:
                self.log(f"  ❌ ERROR: {test_name} - {str(e)}", "ERROR")
                overall_success = False
            
            time.sleep(2)  # Brief pause between test categories
        
        # Generate final report
        report = self.generate_test_report()
        
        self.log("🎯 Test Suite Completed", "COMPLETE")
        return overall_success, report

def main():
    """Main test execution function."""
    print("🧪 Agent Chain Mainnet Pre-launch Testing")
    print("="*50)
    
    # Initialize test suite
    test_suite = MainnetTestSuite()
    
    # Run all tests
    success, report = test_suite.run_full_test_suite()
    
    # Final status
    if success and all(report["mainnet_readiness"].values()):
        print("\n🎉 ALL TESTS PASSED - MAINNET READY!")
        print("✅ Agent Chain is ready for mainnet launch")
        return 0
    else:
        print("\n⚠️ SOME TESTS FAILED - MAINNET NOT READY")
        print("❌ Please address issues before mainnet launch")
        return 1

if __name__ == "__main__":
    exit(main())
