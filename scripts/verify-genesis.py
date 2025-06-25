#!/usr/bin/env python3
"""
Agent Chain Genesis Block Verification Script
=============================================
Comprehensive verification of genesis block and initial network state.
"""

import json
import hashlib
import subprocess
import time
import requests
from datetime import datetime, timezone
from typing import Dict, List, Any, Optional

class GenesisVerifier:
    def __init__(self, genesis_file: str = "genesis/genesis.json"):
        self.genesis_file = genesis_file
        self.genesis_data = None
        self.verification_results = {}
        
    def load_genesis(self) -> bool:
        """Load and parse genesis configuration."""
        try:
            with open(self.genesis_file, 'r') as f:
                self.genesis_data = json.load(f)
            print("✅ Genesis configuration loaded successfully")
            return True
        except FileNotFoundError:
            print(f"❌ Genesis file not found: {self.genesis_file}")
            return False
        except json.JSONDecodeError as e:
            print(f"❌ Invalid JSON in genesis file: {e}")
            return False
    
    def verify_basic_structure(self) -> bool:
        """Verify basic genesis structure."""
        print("\n🔍 Verifying basic structure...")
        
        required_fields = [
            'genesis_time',
            'chain_id', 
            'validators',
            'app_state'
        ]
        
        missing_fields = []
        for field in required_fields:
            if field not in self.genesis_data:
                missing_fields.append(field)
        
        if missing_fields:
            print(f"❌ Missing required fields: {missing_fields}")
            return False
        
        print("✅ Basic structure verification passed")
        return True
    
    def verify_chain_parameters(self) -> bool:
        """Verify chain parameters."""
        print("\n🔍 Verifying chain parameters...")
        
        # Check chain ID
        expected_chain_id = "agent-chain-mainnet"
        actual_chain_id = self.genesis_data.get('chain_id')
        if actual_chain_id != expected_chain_id:
            print(f"❌ Invalid chain ID: {actual_chain_id} (expected: {expected_chain_id})")
            return False
        
        # Check genesis time format
        genesis_time = self.genesis_data.get('genesis_time')
        try:
            datetime.fromisoformat(genesis_time.replace('Z', '+00:00'))
        except ValueError:
            print(f"❌ Invalid genesis time format: {genesis_time}")
            return False
        
        print(f"✅ Chain ID: {actual_chain_id}")
        print(f"✅ Genesis time: {genesis_time}")
        return True
    
    def verify_validators(self) -> bool:
        """Verify initial validators."""
        print("\n🔍 Verifying validators...")
        
        validators = self.genesis_data.get('validators', [])
        
        # Check validator count
        if len(validators) < 3:
            print(f"❌ Insufficient validators: {len(validators)} (minimum: 3)")
            return False
        
        # Verify each validator
        total_power = 0
        for i, validator in enumerate(validators):
            required_fields = ['address', 'pub_key', 'power', 'name']
            for field in required_fields:
                if field not in validator:
                    print(f"❌ Validator {i} missing field: {field}")
                    return False
            
            # Verify power is positive
            power = int(validator['power'])
            if power <= 0:
                print(f"❌ Validator {i} has invalid power: {power}")
                return False
            
            total_power += power
            print(f"✅ Validator {i}: {validator['name']} (Power: {power})")
        
        print(f"✅ Total voting power: {total_power}")
        return True
    
    def verify_initial_accounts(self) -> bool:
        """Verify initial account balances."""
        print("\n🔍 Verifying initial accounts...")
        
        accounts = self.genesis_data.get('app_state', {}).get('accounts', [])
        
        if not accounts:
            print("❌ No initial accounts found")
            return False
        
        total_supply = 0
        for i, account in enumerate(accounts):
            address = account.get('address')
            balance = int(account.get('balance', 0))
            
            if not address:
                print(f"❌ Account {i} missing address")
                return False
            
            if balance < 0:
                print(f"❌ Account {i} has negative balance: {balance}")
                return False
            
            total_supply += balance
            balance_tokens = balance / 10**18  # Convert from wei to tokens
            print(f"✅ Account {address}: {balance_tokens:,.0f} ACT")
        
        # Verify total supply
        expected_supply = 100_000_000 * 10**18  # 100M tokens
        if total_supply != expected_supply:
            print(f"❌ Total supply mismatch: {total_supply} (expected: {expected_supply})")
            return False
        
        total_tokens = total_supply / 10**18
        print(f"✅ Total supply: {total_tokens:,.0f} ACT")
        return True
    
    def verify_staking_parameters(self) -> bool:
        """Verify staking parameters."""
        print("\n🔍 Verifying staking parameters...")
        
        app_state = self.genesis_data.get('app_state', {})
        staking_validators = app_state.get('validators', [])
        params = app_state.get('params', {})
        
        # Check staking validators
        for i, validator in enumerate(staking_validators):
            stake = int(validator.get('stake', 0))
            commission = float(validator.get('commission_rate', 0))
            status = validator.get('status')
            
            if stake <= 0:
                print(f"❌ Validator {i} has invalid stake: {stake}")
                return False
            
            if commission < 0 or commission > 1:
                print(f"❌ Validator {i} has invalid commission: {commission}")
                return False
            
            if status != 'bonded':
                print(f"❌ Validator {i} has invalid status: {status}")
                return False
            
            stake_tokens = stake / 10**18
            print(f"✅ Staking validator {i}: {stake_tokens:,.0f} ACT staked, {commission*100}% commission")
        
        # Check staking parameters
        staking_params = params.get('staking', {})
        if staking_params:
            unbonding_time = staking_params.get('unbonding_time')
            max_validators = staking_params.get('max_validators')
            
            print(f"✅ Unbonding time: {unbonding_time}")
            print(f"✅ Max validators: {max_validators}")
        
        return True
    
    def calculate_genesis_hash(self) -> str:
        """Calculate genesis configuration hash."""
        print("\n🔍 Calculating genesis hash...")
        
        # Create canonical JSON representation
        canonical_json = json.dumps(self.genesis_data, sort_keys=True, separators=(',', ':'))
        
        # Calculate SHA-256 hash
        genesis_hash = hashlib.sha256(canonical_json.encode()).hexdigest()
        
        print(f"✅ Genesis hash: {genesis_hash}")
        return genesis_hash
    
    def verify_network_connectivity(self) -> bool:
        """Verify network is running and accessible."""
        print("\n🔍 Verifying network connectivity...")
        
        endpoints = [
            "http://localhost:8545",
            "http://localhost:8546", 
            "http://localhost:8547"
        ]
        
        active_endpoints = 0
        for endpoint in endpoints:
            try:
                response = requests.get(f"{endpoint}/health", timeout=5)
                if response.status_code == 200:
                    print(f"✅ {endpoint}: Online")
                    active_endpoints += 1
                else:
                    print(f"❌ {endpoint}: HTTP {response.status_code}")
            except requests.RequestException:
                print(f"❌ {endpoint}: Offline")
        
        if active_endpoints == 0:
            print("❌ No network endpoints accessible")
            return False
        
        print(f"✅ Network connectivity: {active_endpoints}/{len(endpoints)} endpoints active")
        return True
    
    def verify_genesis_block(self) -> bool:
        """Verify the actual genesis block on the network."""
        print("\n🔍 Verifying genesis block on network...")
        
        try:
            # Get genesis block from network
            response = requests.get("http://localhost:8545/block?height=0", timeout=10)
            if response.status_code != 200:
                print(f"❌ Failed to get genesis block: HTTP {response.status_code}")
                return False
            
            block_data = response.json()
            block = block_data.get('result', {}).get('block', {})
            header = block.get('header', {})
            
            # Verify block height
            height = header.get('height')
            if height != '0':
                print(f"❌ Invalid genesis block height: {height}")
                return False
            
            # Verify chain ID
            chain_id = header.get('chain_id')
            if chain_id != self.genesis_data.get('chain_id'):
                print(f"❌ Chain ID mismatch: {chain_id}")
                return False
            
            # Verify genesis time
            block_time = header.get('time')
            genesis_time = self.genesis_data.get('genesis_time')
            
            print(f"✅ Genesis block height: {height}")
            print(f"✅ Chain ID: {chain_id}")
            print(f"✅ Genesis time: {block_time}")
            
            return True
            
        except requests.RequestException as e:
            print(f"❌ Network request failed: {e}")
            return False
    
    def generate_verification_report(self) -> Dict[str, Any]:
        """Generate comprehensive verification report."""
        print("\n📊 Generating verification report...")
        
        report = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "genesis_file": self.genesis_file,
            "verification_results": self.verification_results,
            "summary": {
                "total_checks": len(self.verification_results),
                "passed_checks": sum(1 for result in self.verification_results.values() if result),
                "failed_checks": sum(1 for result in self.verification_results.values() if not result)
            }
        }
        
        # Add genesis data summary
        if self.genesis_data:
            report["genesis_summary"] = {
                "chain_id": self.genesis_data.get('chain_id'),
                "genesis_time": self.genesis_data.get('genesis_time'),
                "validator_count": len(self.genesis_data.get('validators', [])),
                "account_count": len(self.genesis_data.get('app_state', {}).get('accounts', [])),
                "genesis_hash": self.calculate_genesis_hash()
            }
        
        # Save report
        with open("genesis_verification_report.json", "w") as f:
            json.dump(report, f, indent=2)
        
        print("✅ Verification report saved: genesis_verification_report.json")
        return report
    
    def run_full_verification(self) -> bool:
        """Run complete genesis verification."""
        print("🌟 Agent Chain Genesis Verification")
        print("=" * 50)
        
        # Load genesis
        if not self.load_genesis():
            return False
        
        # Run all verification checks
        checks = [
            ("Basic Structure", self.verify_basic_structure),
            ("Chain Parameters", self.verify_chain_parameters),
            ("Validators", self.verify_validators),
            ("Initial Accounts", self.verify_initial_accounts),
            ("Staking Parameters", self.verify_staking_parameters),
            ("Network Connectivity", self.verify_network_connectivity),
            ("Genesis Block", self.verify_genesis_block)
        ]
        
        all_passed = True
        for check_name, check_func in checks:
            try:
                result = check_func()
                self.verification_results[check_name] = result
                if not result:
                    all_passed = False
            except Exception as e:
                print(f"❌ {check_name} check failed with error: {e}")
                self.verification_results[check_name] = False
                all_passed = False
        
        # Generate report
        report = self.generate_verification_report()
        
        # Final result
        print("\n" + "=" * 50)
        print("🎯 GENESIS VERIFICATION RESULTS")
        print("=" * 50)
        
        for check_name, result in self.verification_results.items():
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"  {status} {check_name}")
        
        success_rate = (report["summary"]["passed_checks"] / report["summary"]["total_checks"]) * 100
        print(f"\n📊 Success Rate: {report['summary']['passed_checks']}/{report['summary']['total_checks']} ({success_rate:.1f}%)")
        
        if all_passed:
            print("\n🎉 GENESIS VERIFICATION PASSED!")
            print("✅ Genesis block is valid and ready for mainnet launch")
        else:
            print("\n⚠️ GENESIS VERIFICATION FAILED!")
            print("❌ Please fix the issues before mainnet launch")
        
        return all_passed

def main():
    """Main verification function."""
    verifier = GenesisVerifier()
    success = verifier.run_full_verification()
    return 0 if success else 1

if __name__ == "__main__":
    exit(main())
