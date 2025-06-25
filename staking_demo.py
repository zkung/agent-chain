#!/usr/bin/env python3
"""
Staking Demo Script
==================
This script demonstrates the complete staking process for becoming a validator
or delegator in the Agent Chain network.
"""

import subprocess
import time
import json

def run_command(cmd, description=""):
    """Run a command and return the result."""
    print(f"🔧 {description}")
    print(f"Command: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, 
                              encoding='utf-8', errors='ignore')
        
        if result.returncode == 0:
            print(f"✅ Success")
            if result.stdout.strip():
                print(f"Output: {result.stdout.strip()}")
        else:
            print(f"❌ Failed")
            if result.stderr.strip():
                print(f"Error: {result.stderr.strip()}")
        
        print("-" * 50)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        print(f"❌ Exception: {e}")
        print("-" * 50)
        return False, "", str(e)

def display_staking_info():
    """Display staking information."""
    print("🔒 AGENT CHAIN STAKING SYSTEM")
    print("=" * 60)
    print("📋 Staking Options:")
    print()
    print("🏛️ Validator Staking:")
    print("  • Minimum stake: 1000 tokens")
    print("  • Role: Active validator")
    print("  • Rewards: ~10% APY + block rewards + transaction fees")
    print("  • Requirements: Run validator node")
    print("  • Responsibilities: Validate transactions and blocks")
    print()
    print("🤝 Delegator Staking:")
    print("  • Minimum stake: 100 tokens")
    print("  • Role: Passive delegator")
    print("  • Rewards: ~8% APY")
    print("  • Requirements: None (no node needed)")
    print("  • Responsibilities: Support network security")
    print()
    print("⏰ Unbonding Period: 7 days")
    print("🔄 Reward Distribution: Daily")
    print()

def demo_validator_staking():
    """Demonstrate validator staking process."""
    print("1️⃣ VALIDATOR STAKING DEMO")
    print("=" * 40)
    
    # Check current balance
    success, stdout, stderr = run_command(["./wallet.exe", "balance"], 
                                         "Checking account balance")
    
    # Stake as validator
    success, stdout, stderr = run_command(["./wallet.exe", "stake", "--amount", "1000", "--role", "validator"], 
                                         "Staking 1000 tokens as validator")
    
    if success:
        print("🎉 Validator staking successful!")
        print("📊 Your node is now eligible to participate in consensus")
        print("💰 You will earn block rewards and transaction fees")
    
    return success

def demo_delegator_staking():
    """Demonstrate delegator staking process."""
    print("2️⃣ DELEGATOR STAKING DEMO")
    print("=" * 40)
    
    # Stake as delegator
    success, stdout, stderr = run_command(["./wallet.exe", "stake", "--amount", "500", "--role", "delegator"], 
                                         "Staking 500 tokens as delegator")
    
    if success:
        print("🎉 Delegator staking successful!")
        print("📊 Your tokens are now supporting network security")
        print("💰 You will earn staking rewards without running a node")
    
    return success

def demo_unstaking():
    """Demonstrate unstaking process."""
    print("3️⃣ UNSTAKING DEMO")
    print("=" * 40)
    
    # Unstake tokens
    success, stdout, stderr = run_command(["./wallet.exe", "stake", "--unstake"], 
                                         "Unstaking all staked tokens")
    
    if success:
        print("🔓 Unstaking initiated!")
        print("⏰ Tokens will be available after 7-day unbonding period")
        print("📅 You can withdraw tokens after the unbonding period")
    
    return success

def create_staking_guide():
    """Create a staking guide file."""
    guide = {
        "staking_guide": {
            "validator": {
                "minimum_stake": 1000,
                "expected_apy": "10%",
                "additional_rewards": ["block_rewards", "transaction_fees"],
                "requirements": ["run_validator_node", "maintain_uptime"],
                "command": "./wallet.exe stake --amount 1000 --role validator"
            },
            "delegator": {
                "minimum_stake": 100,
                "expected_apy": "8%",
                "additional_rewards": [],
                "requirements": ["none"],
                "command": "./wallet.exe stake --amount 500 --role delegator"
            },
            "unstaking": {
                "unbonding_period": "7 days",
                "command": "./wallet.exe stake --unstake",
                "note": "Tokens locked during unbonding period"
            }
        },
        "reward_schedule": {
            "distribution": "daily",
            "calculation": "proportional_to_stake",
            "validator_bonus": "block_rewards + transaction_fees"
        },
        "best_practices": [
            "Start with delegator staking to learn the system",
            "Ensure sufficient balance before validator staking",
            "Monitor node uptime for validator rewards",
            "Plan for unbonding period when unstaking"
        ]
    }
    
    with open("staking_guide.json", "w") as f:
        json.dump(guide, f, indent=2)
    
    print("📝 Staking guide saved to: staking_guide.json")

def main():
    """Main staking demo function."""
    print("🔒 Agent Chain Staking System Demo")
    print("=" * 60)
    print("Demonstrating validator and delegator staking")
    print("=" * 60)
    
    # Display staking information
    display_staking_info()
    
    # Demo validator staking
    validator_success = demo_validator_staking()
    print()
    
    # Demo delegator staking  
    delegator_success = demo_delegator_staking()
    print()
    
    # Demo unstaking
    unstaking_success = demo_unstaking()
    print()
    
    # Create staking guide
    create_staking_guide()
    
    # Final summary
    print("\n" + "=" * 60)
    print("🎉 STAKING DEMO COMPLETED")
    print("=" * 60)
    
    if validator_success and delegator_success:
        print("✅ All staking operations successful!")
        print()
        print("📊 Staking Summary:")
        print("  • Validator stake: 1000 tokens ✅")
        print("  • Delegator stake: 500 tokens ✅")
        print("  • Total staked: 1500 tokens")
        print("  • Expected rewards: ~10% APY (validator) + ~8% APY (delegator)")
        print()
        print("🏛️ Validator Benefits:")
        print("  • Participate in consensus rounds")
        print("  • Earn block rewards for each validated block")
        print("  • Earn transaction fees from processed transactions")
        print("  • Higher APY due to active participation")
        print()
        print("🤝 Delegator Benefits:")
        print("  • Passive income from staking rewards")
        print("  • Support network security without technical requirements")
        print("  • Lower risk compared to validator staking")
        print()
        print("📝 Next Steps:")
        print("  1. Monitor staking rewards: ./wallet.exe balance")
        print("  2. Check validator status: Monitor node consensus participation")
        print("  3. Claim rewards: Rewards auto-compound or can be claimed")
        print("  4. Unstake when needed: ./wallet.exe stake --unstake")
        
        return 0
    else:
        print("❌ Some staking operations failed")
        print("🔧 Please check wallet configuration and balance")
        return 1

if __name__ == "__main__":
    exit(main())
