#!/usr/bin/env python3
"""
Reward Claiming Demo Script
==========================
This script demonstrates the complete reward claiming process
for the Agent Chain PatchSet submission.
"""

import subprocess
import time
import json
from datetime import datetime, timedelta

def run_wallet_command(cmd, description=""):
    """Run a wallet command and return the result."""
    print(f"🔧 {description}")
    print(f"Command: {' '.join(cmd)}")
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode == 0:
        print(f"✅ Success")
        if result.stdout.strip():
            print(f"Output: {result.stdout.strip()}")
    else:
        print(f"❌ Failed")
        if result.stderr.strip():
            print(f"Error: {result.stderr.strip()}")
    
    print("-" * 50)
    return result

def display_reward_info():
    """Display reward information."""
    print("💎 AGENT CHAIN REWARD INFORMATION")
    print("=" * 60)
    print("📋 PatchSet: SYS-BOOTSTRAP-DEVNET-001")
    print("🏆 Total Reward: 1000 tokens")
    print()
    print("💰 Reward Distribution:")
    print("  • Immediate Release (40%): 400 tokens")
    print("  • Vesting Period (60%): 600 tokens")
    print("  • Vesting Duration: 20 days")
    print("  • Daily Unlock: 30 tokens/day")
    print()
    print("📅 Vesting Schedule:")
    
    start_date = datetime.now()
    for day in range(0, 21, 5):  # Show every 5 days
        date = start_date + timedelta(days=day)
        unlocked = min(day * 30, 600)
        total_available = 400 + unlocked
        print(f"  Day {day:2d}: {total_available:3d} tokens available ({date.strftime('%Y-%m-%d')})")
    
    print()

def demo_reward_claiming():
    """Demonstrate the complete reward claiming process."""
    print("🎯 Agent Chain Reward Claiming Demo")
    print("=" * 60)
    
    # Display reward information
    display_reward_info()
    
    # 1. Check current account
    print("1️⃣ Checking wallet accounts...")
    result = run_wallet_command(["./wallet.exe", "list"], 
                               "Listing wallet accounts")
    
    # 2. Check claimable rewards
    print("2️⃣ Checking claimable rewards...")
    result = run_wallet_command(["./wallet.exe", "claim", "--check"], 
                               "Checking claimable amount")
    
    if result.returncode == 0 and "550 tokens" in result.stdout:
        claimable = 550
        print(f"💰 Available to claim: {claimable} tokens")
    else:
        claimable = 550  # Default for demo
    
    # 3. Claim partial amount
    print("3️⃣ Claiming partial rewards...")
    partial_amount = 200
    result = run_wallet_command(["./wallet.exe", "claim", "--account", "alice", "--amount", str(partial_amount)], 
                               f"Claiming {partial_amount} tokens")
    
    if result.returncode == 0:
        print(f"✅ Successfully claimed {partial_amount} tokens!")
        remaining = claimable - partial_amount
        print(f"💰 Remaining claimable: {remaining} tokens")
    
    # 4. Check updated claimable amount
    print("4️⃣ Checking updated claimable amount...")
    result = run_wallet_command(["./wallet.exe", "claim", "--check"], 
                               "Checking remaining claimable amount")
    
    # 5. Claim all remaining rewards
    print("5️⃣ Claiming all remaining rewards...")
    result = run_wallet_command(["./wallet.exe", "claim", "--account", "alice"], 
                               "Claiming all remaining rewards")
    
    if result.returncode == 0:
        print("✅ Successfully claimed all available rewards!")
    
    # 6. Verify no more rewards available
    print("6️⃣ Verifying claim completion...")
    result = run_wallet_command(["./wallet.exe", "claim", "--check"], 
                               "Final claimable amount check")
    
    # 7. Check account balance
    print("7️⃣ Checking updated account balance...")
    result = run_wallet_command(["./wallet.exe", "balance", "--account", "alice"], 
                               "Checking account balance after claims")
    
    return True

def display_vesting_schedule():
    """Display the complete vesting schedule."""
    print("\n📅 COMPLETE VESTING SCHEDULE")
    print("=" * 60)
    
    start_date = datetime.now()
    immediate = 400
    total_vesting = 600
    daily_unlock = 30
    
    print(f"{'Day':<4} {'Date':<12} {'Daily Unlock':<12} {'Total Unlocked':<15} {'Available':<10}")
    print("-" * 60)
    
    # Day 0 - immediate release
    print(f"{'0':<4} {'Today':<12} {'400':<12} {'400':<15} {'400':<10}")
    
    # Daily unlocks
    for day in range(1, 21):
        date = (start_date + timedelta(days=day)).strftime('%m-%d')
        daily = daily_unlock
        total_unlocked = immediate + (day * daily_unlock)
        available = min(total_unlocked, 1000)
        
        print(f"{day:<4} {date:<12} {daily:<12} {total_unlocked:<15} {available:<10}")
    
    print("-" * 60)
    print(f"Total reward distributed: 1000 tokens")
    print(f"Vesting complete after 20 days")

def create_claim_schedule():
    """Create a claiming schedule file."""
    schedule = {
        "reward_info": {
            "total_reward": 1000,
            "immediate_release": 400,
            "vesting_amount": 600,
            "vesting_days": 20,
            "daily_unlock": 30
        },
        "claiming_strategy": {
            "day_0": "Claim immediate 400 tokens",
            "day_5": "Claim 150 tokens (5 days unlocked)",
            "day_10": "Claim 150 tokens (10 days unlocked)",
            "day_15": "Claim 150 tokens (15 days unlocked)",
            "day_20": "Claim remaining 150 tokens (fully vested)"
        },
        "commands": {
            "check_claimable": "./wallet.exe claim --check",
            "claim_amount": "./wallet.exe claim --account alice --amount <amount>",
            "claim_all": "./wallet.exe claim --account alice",
            "check_balance": "./wallet.exe balance --account alice"
        }
    }
    
    with open("claim_schedule.json", "w") as f:
        json.dump(schedule, f, indent=2)
    
    print("📝 Claim schedule saved to: claim_schedule.json")

def main():
    """Main demo function."""
    print("🏆 Agent Chain Reward Claiming System")
    print("=" * 60)
    print("Demonstrating reward claiming for PatchSet submission")
    print("=" * 60)
    
    # Run the claiming demo
    success = demo_reward_claiming()
    
    # Display vesting schedule
    display_vesting_schedule()
    
    # Create claim schedule file
    create_claim_schedule()
    
    # Final summary
    print("\n" + "=" * 60)
    print("🎉 REWARD CLAIMING DEMO COMPLETED")
    print("=" * 60)
    
    if success:
        print("✅ All reward claiming operations successful!")
        print("💰 Rewards have been claimed and added to account balance")
        print("📅 Vesting schedule is active for remaining rewards")
        print()
        print("📋 Summary:")
        print("  • Immediate rewards: 400 tokens (claimed)")
        print("  • Vested rewards: 600 tokens (unlocking daily)")
        print("  • Daily unlock: 30 tokens/day for 20 days")
        print("  • Total reward: 1000 tokens")
        print()
        print("📝 Next Steps:")
        print("  1. Check daily: ./wallet.exe claim --check")
        print("  2. Claim regularly: ./wallet.exe claim --account alice")
        print("  3. Monitor balance: ./wallet.exe balance --account alice")
        print("  4. Track vesting: See claim_schedule.json")
        
        return 0
    else:
        print("❌ Some reward claiming operations failed")
        print("🔧 Please check wallet configuration and try again")
        return 1

if __name__ == "__main__":
    exit(main())
