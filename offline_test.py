#!/usr/bin/env python3
"""
Offline Test Script for Agent Chain
===================================
This script performs validation tests without requiring network access
"""

import os
import json
import sys
from pathlib import Path

class OfflineValidator:
    def __init__(self):
        self.test_results = {}
        self.errors = []
        self.warnings = []
    
    def log(self, message, level="INFO"):
        prefix = {
            "INFO": "[INFO]",
            "PASS": "[PASS]", 
            "FAIL": "[FAIL]",
            "WARN": "[WARN]"
        }
        print(f"{prefix.get(level, '[INFO]')} {message}")
    
    def test_file_structure(self):
        """Test that all required files exist"""
        self.log("Testing file structure...")
        
        required_files = [
            "go.mod",
            "Makefile", 
            "README.md",
            "bootstrap.sh",
            "bootstrap.ps1",
            "specs/SYS-BOOTSTRAP-DEVNET-001.json",
            "cmd/node/main.go",
            "cmd/wallet/main.go",
            "pkg/types/types.go",
            "pkg/crypto/crypto.go",
            "pkg/blockchain/blockchain.go",
            "pkg/network/network.go",
            "pkg/consensus/consensus.go",
            "pkg/wallet/wallet.go"
        ]
        
        missing_files = []
        for file_path in required_files:
            if not os.path.exists(file_path):
                missing_files.append(file_path)
        
        if missing_files:
            self.log(f"Missing files: {missing_files}", "FAIL")
            self.test_results['file_structure'] = False
            return False
        
        self.log("All required files present", "PASS")
        self.test_results['file_structure'] = True
        return True
    
    def test_go_mod(self):
        """Test go.mod file validity"""
        self.log("Testing go.mod file...")
        
        try:
            with open('go.mod', 'r') as f:
                content = f.read()
            
            if 'module agent-chain' not in content:
                self.log("go.mod missing module declaration", "FAIL")
                return False
            
            if 'go 1.21' not in content:
                self.log("go.mod missing Go version", "WARN")
            
            required_deps = [
                'github.com/libp2p/go-libp2p',
                'github.com/spf13/cobra',
                'github.com/gorilla/mux'
            ]
            
            for dep in required_deps:
                if dep not in content:
                    self.log(f"Missing dependency: {dep}", "WARN")
            
            self.log("go.mod file valid", "PASS")
            self.test_results['go_mod'] = True
            return True
            
        except Exception as e:
            self.log(f"Error reading go.mod: {e}", "FAIL")
            self.test_results['go_mod'] = False
            return False
    
    def test_spec_file(self):
        """Test specification file"""
        self.log("Testing specification file...")
        
        spec_file = "specs/SYS-BOOTSTRAP-DEVNET-001.json"
        
        try:
            with open(spec_file, 'r', encoding='utf-8') as f:
                spec = json.load(f)
            
            required_fields = [
                'id', 'title', 'description', 'acceptance_criteria',
                'time_limit_ms', 'memory_limit_mb', 'reward'
            ]
            
            missing_fields = []
            for field in required_fields:
                if field not in spec:
                    missing_fields.append(field)
            
            if missing_fields:
                self.log(f"Missing spec fields: {missing_fields}", "FAIL")
                return False
            
            # Check specific values
            if spec.get('time_limit_ms') != 420000:  # 7 minutes
                self.log("Unexpected time limit", "WARN")
            
            if spec.get('memory_limit_mb') != 1024:  # 1GB
                self.log("Unexpected memory limit", "WARN")
            
            self.log("Specification file valid", "PASS")
            self.test_results['spec_file'] = True
            return True
            
        except json.JSONDecodeError as e:
            self.log(f"Invalid JSON in spec file: {e}", "FAIL")
            self.test_results['spec_file'] = False
            return False
        except Exception as e:
            self.log(f"Error reading spec file: {e}", "FAIL")
            self.test_results['spec_file'] = False
            return False
    
    def test_go_syntax(self):
        """Test Go file syntax"""
        self.log("Testing Go file syntax...")
        
        go_files = []
        for root, dirs, files in os.walk('.'):
            for file in files:
                if file.endswith('.go'):
                    go_files.append(os.path.join(root, file))
        
        syntax_errors = []
        
        for go_file in go_files:
            try:
                with open(go_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Basic syntax checks
                if 'package ' not in content:
                    syntax_errors.append(f"{go_file}: missing package declaration")
                
                # Check for balanced braces (simple check)
                open_braces = content.count('{')
                close_braces = content.count('}')
                if open_braces != close_braces:
                    syntax_errors.append(f"{go_file}: unbalanced braces")
                
            except Exception as e:
                syntax_errors.append(f"{go_file}: {e}")
        
        if syntax_errors:
            for error in syntax_errors:
                self.log(error, "FAIL")
            self.test_results['go_syntax'] = False
            return False
        
        self.log(f"All {len(go_files)} Go files have valid syntax", "PASS")
        self.test_results['go_syntax'] = True
        return True
    
    def test_bootstrap_scripts(self):
        """Test bootstrap scripts exist and have basic structure"""
        self.log("Testing bootstrap scripts...")
        
        scripts = {
            'bootstrap.sh': ['#!/bin/bash', 'set -e'],
            'bootstrap.ps1': ['param(', 'Write-Host']
        }
        
        for script, expected_content in scripts.items():
            try:
                with open(script, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                missing_content = []
                for expected in expected_content:
                    if expected not in content:
                        missing_content.append(expected)
                
                if missing_content:
                    self.log(f"{script}: missing expected content: {missing_content}", "WARN")
                else:
                    self.log(f"{script}: structure valid", "PASS")
                    
            except Exception as e:
                self.log(f"Error reading {script}: {e}", "FAIL")
                self.test_results['bootstrap_scripts'] = False
                return False
        
        self.test_results['bootstrap_scripts'] = True
        return True
    
    def test_docker_files(self):
        """Test Docker configuration files"""
        self.log("Testing Docker files...")
        
        docker_files = ['Dockerfile', 'docker-compose.yml']
        
        for docker_file in docker_files:
            if not os.path.exists(docker_file):
                self.log(f"Missing {docker_file}", "FAIL")
                self.test_results['docker_files'] = False
                return False
            
            try:
                with open(docker_file, 'r') as f:
                    content = f.read()
                
                if docker_file == 'Dockerfile':
                    if 'FROM golang:' not in content:
                        self.log("Dockerfile missing Go base image", "WARN")
                    if 'COPY' not in content:
                        self.log("Dockerfile missing COPY instruction", "WARN")
                
                elif docker_file == 'docker-compose.yml':
                    if 'version:' not in content:
                        self.log("docker-compose.yml missing version", "WARN")
                    if 'services:' not in content:
                        self.log("docker-compose.yml missing services", "FAIL")
                        return False
                
            except Exception as e:
                self.log(f"Error reading {docker_file}: {e}", "FAIL")
                self.test_results['docker_files'] = False
                return False
        
        self.log("Docker files valid", "PASS")
        self.test_results['docker_files'] = True
        return True
    
    def test_makefile(self):
        """Test Makefile structure"""
        self.log("Testing Makefile...")
        
        try:
            with open('Makefile', 'r') as f:
                content = f.read()
            
            required_targets = ['build', 'clean', 'test']
            missing_targets = []
            
            for target in required_targets:
                if f"{target}:" not in content:
                    missing_targets.append(target)
            
            if missing_targets:
                self.log(f"Makefile missing targets: {missing_targets}", "WARN")
            
            self.log("Makefile structure valid", "PASS")
            self.test_results['makefile'] = True
            return True
            
        except Exception as e:
            self.log(f"Error reading Makefile: {e}", "FAIL")
            self.test_results['makefile'] = False
            return False
    
    def run_all_tests(self):
        """Run all offline tests"""
        self.log("Starting Agent Chain Offline Validation")
        self.log("=" * 50)
        
        tests = [
            self.test_file_structure,
            self.test_go_mod,
            self.test_spec_file,
            self.test_go_syntax,
            self.test_bootstrap_scripts,
            self.test_docker_files,
            self.test_makefile
        ]
        
        passed = 0
        total = len(tests)
        
        for test in tests:
            try:
                if test():
                    passed += 1
            except Exception as e:
                self.log(f"Test error: {e}", "FAIL")
        
        self.log("=" * 50)
        self.log(f"Test Results: {passed}/{total} tests passed")
        
        if passed == total:
            self.log("🎉 All offline tests passed!", "PASS")
            return True
        else:
            self.log(f"⚠️ {total - passed} test(s) failed", "WARN")
            return False

if __name__ == "__main__":
    validator = OfflineValidator()
    success = validator.run_all_tests()
    sys.exit(0 if success else 1)
