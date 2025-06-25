#!/usr/bin/env python3
"""
Performance Test Script for Agent Chain
=======================================

This script monitors resource usage during bootstrap and operation
to ensure compliance with memory and performance requirements.
"""

import psutil
import time
import subprocess
import os
import json
import sys
from typing import Dict, List, Tuple

class PerformanceMonitor:
    def __init__(self):
        self.memory_limit_mb = 1024  # 1GB as per spec
        self.measurements = []
        self.node_processes = []
        
    def log(self, message: str):
        print(f"[PERF] {message}")
    
    def error(self, message: str):
        print(f"[ERROR] {message}")
        sys.exit(1)
    
    def find_agent_chain_processes(self) -> List[psutil.Process]:
        """Find all Agent Chain related processes"""
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                cmdline = ' '.join(proc.info['cmdline'] or [])
                if any(keyword in cmdline.lower() for keyword in ['agent-chain', 'node', 'bootstrap']):
                    if 'bin/node' in cmdline or 'bootstrap' in cmdline:
                        processes.append(proc)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        return processes
    
    def measure_memory_usage(self) -> Dict[str, float]:
        """Measure current memory usage of Agent Chain processes"""
        processes = self.find_agent_chain_processes()
        total_memory_mb = 0
        process_details = {}
        
        for proc in processes:
            try:
                memory_info = proc.memory_info()
                memory_mb = memory_info.rss / 1024 / 1024  # Convert to MB
                total_memory_mb += memory_mb
                
                process_details[f"PID_{proc.pid}"] = {
                    'name': proc.name(),
                    'memory_mb': memory_mb,
                    'cmdline': ' '.join(proc.cmdline()[:3])  # First 3 args
                }
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        return {
            'total_memory_mb': total_memory_mb,
            'process_count': len(processes),
            'processes': process_details,
            'timestamp': time.time()
        }
    
    def measure_system_resources(self) -> Dict[str, float]:
        """Measure overall system resource usage"""
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('.')
        
        return {
            'cpu_percent': cpu_percent,
            'memory_total_gb': memory.total / 1024 / 1024 / 1024,
            'memory_used_gb': memory.used / 1024 / 1024 / 1024,
            'memory_percent': memory.percent,
            'disk_free_gb': disk.free / 1024 / 1024 / 1024,
            'timestamp': time.time()
        }
    
    def start_monitoring(self, duration_seconds: int = 300):
        """Start monitoring performance for specified duration"""
        self.log(f"Starting performance monitoring for {duration_seconds} seconds...")
        
        start_time = time.time()
        max_memory_usage = 0
        
        while time.time() - start_time < duration_seconds:
            # Measure Agent Chain specific usage
            agent_memory = self.measure_memory_usage()
            system_resources = self.measure_system_resources()
            
            measurement = {
                'elapsed_time': time.time() - start_time,
                'agent_chain': agent_memory,
                'system': system_resources
            }
            
            self.measurements.append(measurement)
            
            # Track maximum memory usage
            current_memory = agent_memory['total_memory_mb']
            if current_memory > max_memory_usage:
                max_memory_usage = current_memory
            
            # Check if memory limit is exceeded
            if current_memory > self.memory_limit_mb:
                self.error(f"Memory limit exceeded: {current_memory:.1f}MB > {self.memory_limit_mb}MB")
            
            # Log current status every 30 seconds
            if len(self.measurements) % 30 == 0:
                self.log(f"Memory usage: {current_memory:.1f}MB, "
                        f"Processes: {agent_memory['process_count']}, "
                        f"CPU: {system_resources['cpu_percent']:.1f}%")
            
            time.sleep(1)
        
        self.log(f"Monitoring completed. Max memory usage: {max_memory_usage:.1f}MB")
        return max_memory_usage
    
    def test_bootstrap_performance(self):
        """Test bootstrap script performance"""
        self.log("Testing bootstrap performance...")
        
        # Find bootstrap script
        bootstrap_script = None
        for script in ['bootstrap.sh', 'bootstrap.ps1']:
            if os.path.exists(script):
                bootstrap_script = script
                break
        
        if not bootstrap_script:
            self.error("No bootstrap script found")
        
        # Start bootstrap process
        if bootstrap_script.endswith('.ps1'):
            cmd = ['pwsh', '-File', bootstrap_script]
        else:
            cmd = ['bash', bootstrap_script]
        
        self.log(f"Starting bootstrap script: {bootstrap_script}")
        start_time = time.time()
        
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, 
                              stderr=subprocess.STDOUT, text=True)
        
        try:
            # Monitor for 5 minutes or until completion
            max_memory = self.start_monitoring(300)
            
            bootstrap_time = time.time() - start_time
            
            # Check if bootstrap completed successfully
            if self.check_nodes_ready():
                self.log(f"✅ Bootstrap completed successfully in {bootstrap_time:.1f} seconds")
                self.log(f"✅ Peak memory usage: {max_memory:.1f}MB (limit: {self.memory_limit_mb}MB)")
            else:
                self.error("Bootstrap did not complete successfully")
            
            return {
                'bootstrap_time': bootstrap_time,
                'max_memory_mb': max_memory,
                'memory_limit_mb': self.memory_limit_mb,
                'success': True
            }
            
        except KeyboardInterrupt:
            self.log("Performance test interrupted")
            return None
        finally:
            # Cleanup
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
    
    def check_nodes_ready(self) -> bool:
        """Check if all nodes are ready"""
        import requests
        
        ports = [8545, 8546, 8547]
        for port in ports:
            try:
                response = requests.get(f"http://127.0.0.1:{port}/health", timeout=5)
                if response.status_code != 200:
                    return False
            except:
                return False
        return True
    
    def test_runtime_performance(self, duration_minutes: int = 10):
        """Test runtime performance of running nodes"""
        self.log(f"Testing runtime performance for {duration_minutes} minutes...")
        
        if not self.check_nodes_ready():
            self.error("Nodes are not ready. Please start the testnet first.")
        
        max_memory = self.start_monitoring(duration_minutes * 60)
        
        return {
            'runtime_duration_minutes': duration_minutes,
            'max_memory_mb': max_memory,
            'memory_limit_mb': self.memory_limit_mb,
            'measurements_count': len(self.measurements)
        }
    
    def generate_report(self, results: Dict):
        """Generate performance test report"""
        report = {
            'test_timestamp': time.time(),
            'memory_limit_mb': self.memory_limit_mb,
            'results': results,
            'measurements': self.measurements[-100:],  # Last 100 measurements
            'summary': {
                'memory_compliance': results.get('max_memory_mb', 0) <= self.memory_limit_mb,
                'time_compliance': results.get('bootstrap_time', 0) <= 300,  # 5 minutes
                'overall_pass': (
                    results.get('max_memory_mb', 0) <= self.memory_limit_mb and
                    results.get('bootstrap_time', 0) <= 300
                )
            }
        }
        
        # Save report
        with open('performance_report.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        self.log("Performance report saved to performance_report.json")
        
        # Print summary
        self.print_summary(report)
        
        return report
    
    def print_summary(self, report: Dict):
        """Print performance test summary"""
        print("\n" + "=" * 60)
        print("PERFORMANCE TEST SUMMARY")
        print("=" * 60)
        
        results = report['results']
        summary = report['summary']
        
        print(f"Bootstrap Time: {results.get('bootstrap_time', 0):.1f}s (limit: 300s)")
        print(f"Peak Memory Usage: {results.get('max_memory_mb', 0):.1f}MB (limit: {self.memory_limit_mb}MB)")
        print(f"Memory Compliance: {'✅ PASS' if summary['memory_compliance'] else '❌ FAIL'}")
        print(f"Time Compliance: {'✅ PASS' if summary['time_compliance'] else '❌ FAIL'}")
        print(f"Overall Result: {'✅ PASS' if summary['overall_pass'] else '❌ FAIL'}")
        
        if summary['overall_pass']:
            print("\n🎉 Performance test passed! Implementation meets resource requirements.")
        else:
            print("\n⚠️ Performance test failed. Please optimize resource usage.")

def main():
    monitor = PerformanceMonitor()
    
    if len(sys.argv) > 1:
        if sys.argv[1] == 'bootstrap':
            # Test bootstrap performance
            results = monitor.test_bootstrap_performance()
        elif sys.argv[1] == 'runtime':
            # Test runtime performance
            duration = int(sys.argv[2]) if len(sys.argv) > 2 else 10
            results = monitor.test_runtime_performance(duration)
        else:
            print("Usage: python performance_test.py [bootstrap|runtime] [duration_minutes]")
            sys.exit(1)
    else:
        # Default: test bootstrap performance
        results = monitor.test_bootstrap_performance()
    
    if results:
        monitor.generate_report(results)

if __name__ == "__main__":
    main()
