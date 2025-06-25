#!/usr/bin/env python3
"""
Fixed Mainnet Test Suite
========================
Updated test suite with fixes for identified issues.
"""

import subprocess
import time
import json
import psutil
import os
from datetime import datetime

class FixedMainnetTestSuite:
    def __init__(self):
        self.test_results = {}
        self.start_time = datetime.now()
        
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
    
    def test_basic_functionality_fixed(self):
        """Test 1: Fixed basic functionality verification."""
        self.log("🧪 Starting Fixed Basic Functionality Tests", "TEST")
        
        tests = [
            ("Network status check", ["python", "network_status_check.py"]),
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
        
        self.test_results["basic_functionality_fixed"] = results
        return all(r["success"] for r in results.values())
    
    def test_security_features_fixed(self):
        """Test 2: Fixed security features validation."""
        self.log("🧪 Starting Fixed Security Tests", "TEST")
        
        results = {}
        
        # Test 1: Invalid address rejection
        self.log("  Testing: Invalid address rejection")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "send",
            "--to", "invalid_address_format",
            "--amount", "1"
        ])
        results["invalid_address_rejection"] = not success  # Should fail
        
        # Test 2: Account creation and signing
        self.log("  Testing: Account creation and signing")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "new", "--name", "test_security_fixed"
        ])
        results["account_creation"] = success
        
        # Test 3: Insufficient balance protection (fixed)
        self.log("  Testing: Insufficient balance protection")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "send",
            "--account", "alice",
            "--to", "0x000000000000000000000000000000000000dEaD",
            "--amount", "999999999"
        ])
        # Check if error message contains "insufficient balance"
        balance_protection = not success and ("insufficient" in stderr.lower() or "balance" in stderr.lower())
        results["balance_protection"] = balance_protection
        
        # Test 4: Zero amount rejection
        self.log("  Testing: Zero amount rejection")
        success, stdout, stderr = self.run_command([
            "./wallet.exe", "send",
            "--account", "alice",
            "--to", "0x000000000000000000000000000000000000dEaD",
            "--amount", "0"
        ])
        results["zero_amount_rejection"] = not success  # Should fail
        
        self.test_results["security_features_fixed"] = results
        return all(results.values())
    
    def test_performance_stress(self):
        """Test 3: Performance stress testing."""
        self.log("🧪 Starting Performance Stress Tests", "TEST")
        
        results = {}
        
        # Test 1: Rapid command execution
        self.log("  Testing: Rapid command execution")
        rapid_success = 0
        start_time = time.time()
        
        for i in range(10):
            success, _, _ = self.run_command(["./wallet.exe", "height"], timeout=5)
            if success:
                rapid_success += 1
            time.sleep(0.5)
        
        execution_time = time.time() - start_time
        results["rapid_execution"] = rapid_success >= 8
        results["execution_time"] = execution_time < 15  # Should complete in 15 seconds
        
        # Test 2: Memory stability
        self.log("  Testing: Memory stability")
        initial_memory = self.get_system_memory_usage()
        
        # Perform multiple operations
        for i in range(5):
            self.run_command(["./wallet.exe", "list"], timeout=5)
            self.run_command(["./wallet.exe", "height"], timeout=5)
            time.sleep(1)
        
        final_memory = self.get_system_memory_usage()
        memory_increase = final_memory - initial_memory
        results["memory_stability"] = memory_increase < 100  # Less than 100MB increase
        
        self.test_results["performance_stress"] = results
        return all(results.values())
    
    def get_system_memory_usage(self):
        """Get current system memory usage in MB."""
        try:
            memory_info = psutil.virtual_memory()
            return memory_info.used / 1024 / 1024  # Convert to MB
        except:
            return 0
    
    def test_wallet_comprehensive(self):
        """Test 4: Comprehensive wallet functionality."""
        self.log("🧪 Starting Comprehensive Wallet Tests", "TEST")
        
        results = {}
        
        # Test all wallet commands
        wallet_tests = [
            ("list_accounts", ["./wallet.exe", "list"]),
            ("check_height", ["./wallet.exe", "height"]),
            ("check_balance", ["./wallet.exe", "balance", "--account", "alice"]),
            ("check_claimable", ["./wallet.exe", "claim", "--check"]),
            ("receive_address", ["./wallet.exe", "receive", "--account", "alice"]),
        ]
        
        for test_name, cmd in wallet_tests:
            self.log(f"  Testing: {test_name}")
            success, stdout, stderr = self.run_command(cmd)
            results[test_name] = success
            status = "✅ PASS" if success else "❌ FAIL"
            self.log(f"    {status}: {test_name}")
        
        self.test_results["wallet_comprehensive"] = results
        return all(results.values())
    
    def test_network_stability(self):
        """Test 5: Network stability over time."""
        self.log("🧪 Starting Network Stability Tests", "TEST")
        
        results = {}
        
        # Test 1: Continuous height monitoring
        self.log("  Testing: Continuous height monitoring (60 seconds)")
        heights = []
        start_time = time.time()
        
        while time.time() - start_time < 60:
            success, stdout, stderr = self.run_command(["./wallet.exe", "height"], timeout=5)
            if success and "Height:" in stdout:
                height = stdout.strip().split(":")[-1].strip()
                heights.append(int(height))
            time.sleep(5)
        
        # Check if heights are increasing (blocks being produced)
        height_increasing = len(heights) >= 10 and heights[-1] > heights[0]
        results["height_increasing"] = height_increasing
        
        # Test 2: Network responsiveness
        self.log("  Testing: Network responsiveness")
        response_times = []
        
        for i in range(5):
            start = time.time()
            success, _, _ = self.run_command(["./wallet.exe", "height"], timeout=10)
            response_time = time.time() - start
            if success:
                response_times.append(response_time)
            time.sleep(2)
        
        avg_response_time = sum(response_times) / len(response_times) if response_times else 10
        results["network_responsiveness"] = avg_response_time < 3.0
        
        self.test_results["network_stability"] = results
        return all(results.values())
    
    def generate_final_report(self):
        """Generate final test report."""
        self.log("📊 Generating Final Test Report", "REPORT")
        
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
                    for r in self.test_results.get("basic_functionality_fixed", {}).values()
                ),
                "security_features": all(self.test_results.get("security_features_fixed", {}).values()),
                "performance_stress": all(self.test_results.get("performance_stress", {}).values()),
                "wallet_comprehensive": all(self.test_results.get("wallet_comprehensive", {}).values()),
                "network_stability": all(self.test_results.get("network_stability", {}).values())
            }
        }
        
        # Save report
        with open("mainnet_test_report_fixed.json", "w") as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        print("\n" + "="*60)
        print("🎯 FIXED MAINNET READINESS TEST REPORT")
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
        
        if mainnet_ready:
            print("\n🎉 ALL SYSTEMS GO!")
            print("✅ Agent Chain is ready for mainnet launch")
            print("🚀 Recommended next steps:")
            print("  1. Deploy to production environment")
            print("  2. Start mainnet with genesis block")
            print("  3. Begin validator onboarding")
            print("  4. Monitor network health")
        
        return report
    
    def run_fixed_test_suite(self):
        """Run the fixed test suite."""
        self.log("🚀 Starting Fixed Agent Chain Mainnet Test Suite", "START")
        
        test_functions = [
            ("Basic Functionality (Fixed)", self.test_basic_functionality_fixed),
            ("Security Features (Fixed)", self.test_security_features_fixed),
            ("Performance Stress", self.test_performance_stress),
            ("Wallet Comprehensive", self.test_wallet_comprehensive),
            ("Network Stability", self.test_network_stability)
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
            
            time.sleep(2)
        
        # Generate final report
        report = self.generate_final_report()
        
        self.log("🎯 Fixed Test Suite Completed", "COMPLETE")
        return overall_success, report

def main():
    """Main test execution function."""
    print("🧪 Agent Chain Fixed Mainnet Pre-launch Testing")
    print("="*50)
    
    # Initialize test suite
    test_suite = FixedMainnetTestSuite()
    
    # Run all tests
    success, report = test_suite.run_fixed_test_suite()
    
    # Final status
    if success and all(report["mainnet_readiness"].values()):
        print("\n🎉 ALL TESTS PASSED - MAINNET READY!")
        return 0
    else:
        print("\n⚠️ SOME TESTS FAILED - REVIEW REQUIRED")
        return 1

if __name__ == "__main__":
    exit(main())
