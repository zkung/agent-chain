#!/usr/bin/env python3
"""
Specification Validation Script for SYS-BOOTSTRAP-DEVNET-001
============================================================

This script validates that the Agent Chain implementation meets all
requirements specified in SYS-BOOTSTRAP-DEVNET-001.json
"""

import json
import os
import subprocess
import sys
import time
import socket
import requests
from pathlib import Path
from typing import List, Dict, Any

class Colors:
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def log(message: str, color: str = Colors.GREEN):
    print(f"{color}[VALIDATE]{Colors.NC} {message}")

def error(message: str):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}")
    sys.exit(1)

def warn(message: str):
    print(f"{Colors.YELLOW}[WARN]{Colors.NC} {message}")

def info(message: str):
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {message}")

class SpecValidator:
    def __init__(self):
        self.spec_file = "specs/SYS-BOOTSTRAP-DEVNET-001.json"
        self.spec = self.load_spec()
        self.bootstrap_script = None
        self.wallet_binary = "wallet"
        self.test_results = {}
        
    def load_spec(self) -> Dict[str, Any]:
        """Load the specification file"""
        if not os.path.exists(self.spec_file):
            error(f"Specification file not found: {self.spec_file}")
        
        with open(self.spec_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def find_bootstrap_script(self) -> str:
        """Find the bootstrap script (bash or PowerShell)"""
        candidates = ["bootstrap.sh", "bootstrap.ps1"]
        for script in candidates:
            if os.path.exists(script):
                return script
        error("No bootstrap script found (bootstrap.sh or bootstrap.ps1)")
    
    def wait_for_port(self, host: str, port: int, timeout: int = 60) -> bool:
        """Wait for a port to become available"""
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
    
    def check_rpc_health(self, port: int) -> bool:
        """Check if RPC endpoint is healthy"""
        try:
            response = requests.get(f"http://127.0.0.1:{port}/health", timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def validate_file_structure(self):
        """Validate required files exist"""
        log("Validating file structure...")
        
        required_files = [
            "go.mod",
            "README.md",
            "Makefile",
            self.spec_file
        ]
        
        for file in required_files:
            if not os.path.exists(file):
                error(f"Required file missing: {file}")
        
        # Check for bootstrap script
        self.bootstrap_script = self.find_bootstrap_script()
        log(f"✅ Found bootstrap script: {self.bootstrap_script}")
        
        # Check if script is executable (Unix-like systems)
        if self.bootstrap_script.endswith('.sh'):
            if not os.access(self.bootstrap_script, os.X_OK):
                warn(f"Bootstrap script {self.bootstrap_script} is not executable")
        
        self.test_results['file_structure'] = True
    
    def validate_build_system(self):
        """Validate that the build system works"""
        log("Validating build system...")
        
        try:
            # Test make build
            result = subprocess.run(['make', 'build'], 
                                  capture_output=True, text=True, timeout=300)
            
            if result.returncode != 0:
                error(f"Build failed: {result.stderr}")
            
            # Check if binaries were created
            expected_binaries = ["bin/node", "bin/wallet"]
            for binary in expected_binaries:
                if not os.path.exists(binary):
                    error(f"Expected binary not found: {binary}")
            
            log("✅ Build system validation passed")
            self.test_results['build_system'] = True
            
        except subprocess.TimeoutExpired:
            error("Build process timed out (>5 minutes)")
        except FileNotFoundError:
            error("Make command not found. Please install build tools.")
    
    def validate_bootstrap_execution(self):
        """Validate bootstrap script execution"""
        log("Validating bootstrap script execution...")
        
        start_time = time.time()
        
        # Start bootstrap script
        if self.bootstrap_script.endswith('.ps1'):
            cmd = ['pwsh', '-File', self.bootstrap_script]
        else:
            cmd = ['bash', self.bootstrap_script]
        
        try:
            # Start the process
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, 
                                  stderr=subprocess.STDOUT, text=True)
            
            # Wait for RPC endpoints to become available
            rpc_ports = [8545, 8546, 8547]
            all_ready = False
            
            for _ in range(300):  # 5 minutes timeout
                if all(self.wait_for_port('127.0.0.1', port, 1) for port in rpc_ports):
                    all_ready = True
                    break
                time.sleep(1)
            
            execution_time = time.time() - start_time
            
            if not all_ready:
                error("RPC endpoints did not become available within 5 minutes")
            
            # Check if execution time meets requirement
            time_limit = self.spec.get('time_limit_ms', 300000) / 1000  # Convert to seconds
            if execution_time > time_limit:
                error(f"Bootstrap took {execution_time:.1f}s, exceeds limit of {time_limit}s")
            
            log(f"✅ Bootstrap completed in {execution_time:.1f} seconds")
            self.test_results['bootstrap_time'] = execution_time
            
            return proc
            
        except Exception as e:
            error(f"Bootstrap execution failed: {e}")
    
    def validate_rpc_endpoints(self):
        """Validate RPC endpoints are working"""
        log("Validating RPC endpoints...")
        
        rpc_ports = [8545, 8546, 8547]
        
        for port in rpc_ports:
            if not self.check_rpc_health(port):
                error(f"RPC endpoint 127.0.0.1:{port} is not healthy")
            log(f"✅ RPC endpoint 127.0.0.1:{port} is healthy")
        
        self.test_results['rpc_endpoints'] = True
    
    def validate_wallet_functionality(self):
        """Validate CLI wallet functionality"""
        log("Validating CLI wallet functionality...")
        
        if not os.path.exists(self.wallet_binary):
            error(f"Wallet binary not found: {self.wallet_binary}")
        
        test_account = "test-validation"
        
        try:
            # Test: Create new account
            result = subprocess.run([
                self.wallet_binary, 'new', '--name', test_account,
                '--data-dir', './test-wallet-data'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0 or 'address' not in result.stdout.lower():
                error(f"Account creation failed: {result.stderr}")
            
            log("✅ Account creation works")
            
            # Test: List accounts
            result = subprocess.run([
                self.wallet_binary, 'list',
                '--data-dir', './test-wallet-data'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0 or test_account not in result.stdout:
                error(f"Account listing failed: {result.stderr}")
            
            log("✅ Account listing works")
            
            # Test: Check balance
            result = subprocess.run([
                self.wallet_binary, 'balance', '--account', test_account,
                '--data-dir', './test-wallet-data'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                warn(f"Balance check failed: {result.stderr}")
            else:
                log("✅ Balance check works")
            
            # Test: Get height
            result = subprocess.run([
                self.wallet_binary, 'height'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                warn(f"Height check failed: {result.stderr}")
            else:
                log("✅ Height check works")
            
            self.test_results['wallet_functionality'] = True
            
        except subprocess.TimeoutExpired:
            error("Wallet command timed out")
        except Exception as e:
            error(f"Wallet validation failed: {e}")
    
    def validate_height_consistency(self):
        """Validate block height consistency across nodes"""
        log("Validating height consistency across nodes...")
        
        heights = []
        rpc_ports = [8545, 8546, 8547]
        
        for port in rpc_ports:
            try:
                result = subprocess.run([
                    self.wallet_binary, 'height', '--rpc', f'http://127.0.0.1:{port}'
                ], capture_output=True, text=True, timeout=10)
                
                if result.returncode == 0:
                    # Extract height from output
                    height_line = [line for line in result.stdout.split('\n') if 'Height:' in line]
                    if height_line:
                        height = height_line[0].split(':')[1].strip()
                        heights.append(height)
                else:
                    heights.append("ERROR")
            except:
                heights.append("TIMEOUT")
        
        # Check consistency
        unique_heights = set(heights)
        if len(unique_heights) == 1 and "ERROR" not in unique_heights and "TIMEOUT" not in unique_heights:
            log(f"✅ All nodes have consistent height: {heights[0]}")
            self.test_results['height_consistency'] = True
        else:
            warn(f"Height inconsistency detected: {heights}")
            self.test_results['height_consistency'] = False
    
    def cleanup(self, proc=None):
        """Cleanup test resources"""
        log("Cleaning up...")
        
        if proc:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
        
        # Clean up test data
        import shutil
        if os.path.exists('./test-wallet-data'):
            shutil.rmtree('./test-wallet-data')
    
    def run_validation(self):
        """Run complete validation suite"""
        info("Starting Agent Chain Specification Validation")
        info(f"Spec ID: {self.spec.get('id', 'Unknown')}")
        info(f"Title: {self.spec.get('title', 'Unknown')}")
        info("=" * 60)
        
        proc = None
        
        try:
            self.validate_file_structure()
            self.validate_build_system()
            proc = self.validate_bootstrap_execution()
            self.validate_rpc_endpoints()
            self.validate_wallet_functionality()
            self.validate_height_consistency()
            
            # Print summary
            self.print_summary()
            
        except KeyboardInterrupt:
            warn("Validation interrupted by user")
        except Exception as e:
            error(f"Validation failed: {e}")
        finally:
            self.cleanup(proc)
    
    def print_summary(self):
        """Print validation summary"""
        info("\n" + "=" * 60)
        info("VALIDATION SUMMARY")
        info("=" * 60)
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results.values() if result is True)
        
        for test_name, result in self.test_results.items():
            status = "✅ PASS" if result is True else "❌ FAIL" if result is False else "⚠️ WARN"
            info(f"{test_name.replace('_', ' ').title()}: {status}")
        
        info(f"\nOverall: {passed_tests}/{total_tests} tests passed")
        
        if passed_tests == total_tests:
            log("🎉 All validation tests passed! Implementation meets specification requirements.")
        else:
            warn(f"⚠️ {total_tests - passed_tests} tests failed or had warnings.")

if __name__ == "__main__":
    validator = SpecValidator()
    validator.run_validation()
