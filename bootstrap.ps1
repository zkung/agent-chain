# Agent Chain Bootstrap Script for Windows PowerShell
# Starts a 3-node local testnet with CLI wallet

param(
    [switch]$Help
)

if ($Help) {
    Write-Host "Agent Chain Bootstrap Script"
    Write-Host "Usage: .\bootstrap.ps1"
    Write-Host "This script starts a 3-node local testnet with CLI wallet"
    exit 0
}

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $ScriptDir "data"
$LogsDir = Join-Path $ScriptDir "logs"
$BinDir = Join-Path $ScriptDir "bin"

# Node configurations
$NODE1_P2P_PORT = 9001
$NODE1_RPC_PORT = 8545
$NODE2_P2P_PORT = 9002
$NODE2_RPC_PORT = 8546
$NODE3_P2P_PORT = 9003
$NODE3_RPC_PORT = 8547

# Global variables for process tracking
$NodeProcesses = @()

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] WARNING: $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Cleanup {
    Write-Log "Cleaning up processes..."
    foreach ($proc in $NodeProcesses) {
        if ($proc -and !$proc.HasExited) {
            try {
                $proc.Kill()
                $proc.WaitForExit(5000)
            }
            catch {
                Write-Warning "Failed to kill process: $_"
            }
        }
    }
    $NodeProcesses.Clear()
}

function Check-Dependencies {
    Write-Log "Checking dependencies..."
    
    # Check if Go is installed
    try {
        $goVersion = & go version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Go is not installed. Please install Go 1.21 or later."
        }
        
        # Extract version number
        if ($goVersion -match "go(\d+\.\d+)") {
            $version = [version]$matches[1]
            if ($version -lt [version]"1.21") {
                Write-Error "Go version $($matches[1]) is too old. Please install Go 1.21 or later."
            }
        }
    }
    catch {
        Write-Error "Failed to check Go version: $_"
    }
    
    Write-Log "✅ Dependencies check passed"
}

function Build-Binaries {
    Write-Log "Building binaries..."
    
    # Create bin directory
    if (!(Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    }
    
    # Build node
    Write-Log "Building node binary..."
    $nodeOutput = Join-Path $BinDir "node.exe"
    & go build -o $nodeOutput ./cmd/node
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build node binary"
    }
    
    # Build wallet
    Write-Log "Building wallet binary..."
    $walletOutput = Join-Path $BinDir "wallet.exe"
    & go build -o $walletOutput ./cmd/wallet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build wallet binary"
    }
    
    # Copy wallet to current directory for tests
    Copy-Item $walletOutput ".\wallet.exe" -Force
    
    Write-Log "✅ Binaries built successfully"
}

function Create-Directories {
    Write-Log "Creating directories..."
    
    @("$DataDir\node1", "$DataDir\node2", "$DataDir\node3", $LogsDir, "configs") | ForEach-Object {
        if (!(Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    
    Write-Log "✅ Directories created"
}

function Generate-Configs {
    Write-Log "Generating node configurations..."
    
    # Node 1 config
    @"
data_dir: "$($DataDir -replace '\\', '/')/node1"
p2p_port: $NODE1_P2P_PORT
rpc_port: $NODE1_RPC_PORT
is_validator: true
boot_nodes: []
"@ | Out-File -FilePath "configs\node1.yaml" -Encoding UTF8
    
    # Node 2 config
    @"
data_dir: "$($DataDir -replace '\\', '/')/node2"
p2p_port: $NODE2_P2P_PORT
rpc_port: $NODE2_RPC_PORT
is_validator: true
boot_nodes:
  - "/ip4/127.0.0.1/tcp/$NODE1_P2P_PORT"
"@ | Out-File -FilePath "configs\node2.yaml" -Encoding UTF8
    
    # Node 3 config
    @"
data_dir: "$($DataDir -replace '\\', '/')/node3"
p2p_port: $NODE3_P2P_PORT
rpc_port: $NODE3_RPC_PORT
is_validator: true
boot_nodes:
  - "/ip4/127.0.0.1/tcp/$NODE1_P2P_PORT"
  - "/ip4/127.0.0.1/tcp/$NODE2_P2P_PORT"
"@ | Out-File -FilePath "configs\node3.yaml" -Encoding UTF8
    
    Write-Log "✅ Node configurations generated"
}

function Start-Nodes {
    Write-Log "Starting nodes..."
    
    $nodeBinary = Join-Path $BinDir "node.exe"
    
    # Start node 1 (Bootstrap node with P2P discovery)
    Write-Log "Starting node 1 (P2P: $NODE1_P2P_PORT, RPC: $NODE1_RPC_PORT)..."
    $node1LogPath = Join-Path $LogsDir "node1.log"
    $node1ErrPath = Join-Path $LogsDir "node1.err"
    $proc1 = Start-Process -FilePath $nodeBinary -ArgumentList "--config", "configs\node1.yaml", "--bootstrap", "--discovery" -RedirectStandardOutput $node1LogPath -RedirectStandardError $node1ErrPath -PassThru -NoNewWindow
    $script:NodeProcesses += $proc1

    Start-Sleep -Seconds 3

    # Start node 2 (Regular node with P2P discovery)
    Write-Log "Starting node 2 (P2P: $NODE2_P2P_PORT, RPC: $NODE2_RPC_PORT)..."
    $node2LogPath = Join-Path $LogsDir "node2.log"
    $node2ErrPath = Join-Path $LogsDir "node2.err"
    $proc2 = Start-Process -FilePath $nodeBinary -ArgumentList "--config", "configs\node2.yaml", "--discovery" -RedirectStandardOutput $node2LogPath -RedirectStandardError $node2ErrPath -PassThru -NoNewWindow
    $script:NodeProcesses += $proc2

    Start-Sleep -Seconds 3

    # Start node 3 (Regular node with P2P discovery)
    Write-Log "Starting node 3 (P2P: $NODE3_P2P_PORT, RPC: $NODE3_RPC_PORT)..."
    $node3LogPath = Join-Path $LogsDir "node3.log"
    $node3ErrPath = Join-Path $LogsDir "node3.err"
    $proc3 = Start-Process -FilePath $nodeBinary -ArgumentList "--config", "configs\node3.yaml", "--discovery" -RedirectStandardOutput $node3LogPath -RedirectStandardError $node3ErrPath -PassThru -NoNewWindow
    $script:NodeProcesses += $proc3
    
    Start-Sleep -Seconds 5
    
    Write-Log "✅ All nodes started"
    Write-Log "Node PIDs: $($proc1.Id), $($proc2.Id), $($proc3.Id)"
}

function Check-Nodes {
    Write-Log "Checking node health..."
    
    $allHealthy = $true
    $ports = @($NODE1_RPC_PORT, $NODE2_RPC_PORT, $NODE3_RPC_PORT)
    
    foreach ($port in $ports) {
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Log "✅ Node on port $port is healthy"
            }
            else {
                Write-Warning "❌ Node on port $port returned status $($response.StatusCode)"
                $allHealthy = $false
            }
        }
        catch {
            Write-Warning "❌ Node on port $port is not responding: $_"
            $allHealthy = $false
        }
    }
    
    if ($allHealthy) {
        Write-Log "✅ All nodes are healthy"
    }
    else {
        Write-Error "Some nodes are not healthy. Check logs in $LogsDir\"
    }
}

function Create-SampleAccount {
    Write-Log "Creating sample wallet account..."
    
    try {
        & .\wallet.exe new --name alice --data-dir .\wallet-data 2>$null | Out-Null
    }
    catch {
        # Ignore errors for sample account creation
    }
    
    Write-Log "✅ Sample account 'alice' created"
    Write-Log "Use '.\wallet.exe list' to see all accounts"
}

function Display-Status {
    Write-Host ""
    Write-Host "🎉 Agent Chain Testnet is running!" -ForegroundColor Blue
    Write-Host ""
    Write-Host "RPC Endpoints:" -ForegroundColor Green
    Write-Host "  Node 1: http://127.0.0.1:$NODE1_RPC_PORT"
    Write-Host "  Node 2: http://127.0.0.1:$NODE2_RPC_PORT"
    Write-Host "  Node 3: http://127.0.0.1:$NODE3_RPC_PORT"
    Write-Host ""
    Write-Host "CLI Wallet Commands:" -ForegroundColor Green
    Write-Host "  .\wallet.exe new --name <name>                    # Create new account"
    Write-Host "  .\wallet.exe list                                 # List accounts"
    Write-Host "  .\wallet.exe balance --account <name>             # Check balance"
    Write-Host "  .\wallet.exe send --account <name> --to <addr> --amount <amount>  # Send tokens"
    Write-Host "  .\wallet.exe height                               # Get blockchain height"
    Write-Host ""
    Write-Host "Logs:" -ForegroundColor Green
    Write-Host "  Node logs: $LogsDir\"
    Write-Host "  Get-Content $LogsDir\node1.log -Wait              # Follow node 1 logs"
    Write-Host ""
    Write-Host "Press Ctrl+C to stop all nodes" -ForegroundColor Yellow
}

function Wait-ForInterrupt {
    try {
        while ($true) {
            Start-Sleep -Seconds 1
        }
    }
    finally {
        Cleanup
    }
}

# Main execution
function Main {
    Write-Log "Starting Agent Chain Bootstrap..."
    
    # Register cleanup on exit
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Cleanup }
    
    try {
        Check-Dependencies
        Build-Binaries
        Create-Directories
        Generate-Configs
        Start-Nodes
        Check-Nodes
        Create-SampleAccount
        Display-Status
        Wait-ForInterrupt
    }
    catch {
        Write-Error "Bootstrap failed: $_"
    }
    finally {
        Cleanup
    }
}

# Run main function
Main
