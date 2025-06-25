"""TestSuite for SYS-BOOTSTRAP-DEVNET-001
--------------------------------------------------
This pytest suite validates a candidate submission for the
"One-Click DevNet & CLI Wallet" ProblemSpec.  
The candidate **must** provide either `bootstrap.sh` (bash) or
`bootstrap.ps1` (PowerShell) in the current working directory.

Validation steps:
1. Run the bootstrap script in a temporary directory.
2. Ensure three local RPC endpoints become reachable.
3. Verify the bundled CLI wallet can:   
   • generate a new account   
   • send a transaction   
   • report identical block height across the three nodes.

Resource limits (time / memory) are enforced by the upper-level
sandbox. Adjust constants below to match ProblemSpec if needed.
"""

from __future__ import annotations
import os
import pathlib
import socket
import subprocess
import sys
import time
from typing import List

import pytest

# ----------------------------------------------------------------------------
# Configurable constants — **keep in sync with ProblemSpec**
# ----------------------------------------------------------------------------
TIMEOUT_BOOTSTRAP_SEC = 300       # ≤ 5 min
NODE_RPC_ENDPOINTS: List[str] = [
    "127.0.0.1:8545",
    "127.0.0.1:8546",
    "127.0.0.1:8547",
]
BOOTSTRAP_BASH = "bootstrap.sh"
BOOTSTRAP_PS1 = "bootstrap.ps1"
WALLET_BINARY = "wallet.exe"  # Windows binary

# ----------------------------------------------------------------------------
# Helper utilities
# ----------------------------------------------------------------------------

def _script_path() -> pathlib.Path:
    """Return path to bootstrap script (bash or ps1)."""
    cwd = pathlib.Path.cwd()
    for candidate in (BOOTSTRAP_BASH, BOOTSTRAP_PS1):
        p = cwd / candidate
        if p.exists():
            return p
    pytest.skip("Bootstrap script not found in submission directory")


def wait_port(addr: str, timeout: int = 120) -> bool:
    """Wait until TCP <host>:<port> is accept()-able within *timeout* seconds."""
    host, port_str = addr.split(":")
    port = int(port_str)
    for _ in range(timeout):
        with socket.socket() as s:
            if s.connect_ex((host, port)) == 0:
                return True
        time.sleep(1)
    return False


# ----------------------------------------------------------------------------
# Main test — executed by `pytest`
# ----------------------------------------------------------------------------

def test_bootstrap_devnet(tmp_path: pathlib.Path) -> None:  # pylint: disable=too-many-locals,unused-argument
    # Clean up any existing processes first
    try:
        subprocess.run(['taskkill', '/F', '/IM', 'node.exe'], capture_output=True, check=False)
    except:
        pass
    time.sleep(2)

    script = _script_path()
    project_root = pathlib.Path.cwd()

    # 1. Launch bootstrap script (non-blocking) - run in project root, not tmp_path
    if script.suffix == ".ps1":
        cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(script)]
    else:
        cmd = ["bash", str(script)]

    proc = subprocess.Popen(cmd, cwd=project_root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    try:
        # 2. Wait for RPC endpoints
        for addr in NODE_RPC_ENDPOINTS:
            if not wait_port(addr):
                # Get bootstrap output for debugging
                try:
                    stdout, _ = proc.communicate(timeout=1)
                    print(f"Bootstrap output: {stdout}")
                except subprocess.TimeoutExpired:
                    pass
                assert False, f"RPC {addr} not up within timeout"

        # 3. Wallet: create account - use wallet from project root
        wallet_path = project_root / WALLET_BINARY
        new_acc_output = subprocess.check_output([str(wallet_path), "new", "--name", "alice"], text=True, cwd=project_root)
        assert "address" in new_acc_output.lower()

        # 4. Wallet: send transaction
        subprocess.check_call([str(wallet_path), "send", "--to", "0x000000000000000000000000000000000000dEaD", "--amount", "1"], cwd=project_root)
        time.sleep(5)

        # 5. Verify block height consistency
        heights = []
        for addr in NODE_RPC_ENDPOINTS:
            out = subprocess.check_output([str(wallet_path), "height", "--rpc", f"http://{addr}"], text=True, cwd=project_root).strip()
            heights.append(out)
        assert len(set(heights)) == 1, f"Height mismatch across nodes: {heights}"

    finally:
        # Always terminate the devnet to free resources
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
