# Agent Chain - 一键加入网络脚本 (Windows)
# One-Click Network Join Script for Windows

param(
    [string]$NodeName = "my-node",
    [int]$P2PPort = 9001,
    [int]$RPCPort = 8545,
    [switch]$Help
)

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Magenta = "Magenta"
    Cyan = "Cyan"
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO", [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $Color
}

function Write-Success { param([string]$Message) Write-Log $Message "SUCCESS" $Colors.Green }
function Write-Info { param([string]$Message) Write-Log $Message "INFO" $Colors.Blue }
function Write-Warning { param([string]$Message) Write-Log $Message "WARNING" $Colors.Yellow }
function Write-Error { param([string]$Message) Write-Log $Message "ERROR" $Colors.Red }
function Write-Step { param([string]$Message) Write-Log $Message "STEP" $Colors.Cyan }
function Write-Network { param([string]$Message) Write-Log $Message "NETWORK" $Colors.Magenta }

# Configuration
$ProjectRoot = $PSScriptRoot
$NodeBinary = Join-Path $ProjectRoot "node.exe"
$WalletBinary = Join-Path $ProjectRoot "wallet.exe"
$DataDir = Join-Path $ProjectRoot "data\$NodeName"

# Show welcome message
function Show-Welcome {
    Write-Host ""
    Write-Host "🌐 ==================================" -ForegroundColor Cyan
    Write-Host "   Agent Chain - 一键加入网络" -ForegroundColor Cyan
    Write-Host "   One-Click Network Join" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Info "欢迎使用 Agent Chain！"
    Write-Info "Welcome to Agent Chain!"
    Write-Host ""
    Write-Info "这个脚本将帮助您："
    Write-Info "This script will help you:"
    Write-Host "  • 🔧 自动构建和配置节点"
    Write-Host "  • 🌐 自动发现并连接到网络"
    Write-Host "  • 💰 创建您的第一个钱包"
    Write-Host "  • 🚀 开始使用区块链"
    Write-Host ""
}

# Show help
function Show-Help {
    Write-Host "Agent Chain - 一键加入网络脚本"
    Write-Host ""
    Write-Host "用法 / Usage:"
    Write-Host "  .\join-network.ps1 [参数]"
    Write-Host ""
    Write-Host "参数 / Parameters:"
    Write-Host "  -NodeName   节点名称 (默认: my-node)"
    Write-Host "  -P2PPort    P2P端口 (默认: 9001)"
    Write-Host "  -RPCPort    RPC端口 (默认: 8545)"
    Write-Host "  -Help       显示帮助信息"
    Write-Host ""
    Write-Host "示例 / Examples:"
    Write-Host "  .\join-network.ps1"
    Write-Host "  .\join-network.ps1 -NodeName alice-node"
    Write-Host "  .\join-network.ps1 -NodeName alice-node -P2PPort 9002 -RPCPort 8546"
    exit 0
}

# Check system requirements
function Test-Requirements {
    Write-Step "检查系统要求 / Checking system requirements..."
    
    # Check Go
    try {
        $goVersion = go version 2>$null
        if ($goVersion) {
            Write-Success "Go 已安装 / Go installed: $goVersion"
        } else {
            throw "Go not found"
        }
    } catch {
        Write-Error "Go 语言未安装 / Go is not installed"
        Write-Info "请安装 Go 1.21+ / Please install Go 1.21+"
        Write-Info "下载地址 / Download: https://golang.org/dl/"
        exit 1
    }
    
    # Check curl (or use Invoke-WebRequest)
    try {
        curl --version 2>$null | Out-Null
        Write-Success "curl 已安装 / curl installed"
    } catch {
        Write-Warning "curl 未安装，将使用 PowerShell 替代 / curl not installed, will use PowerShell alternative"
    }
    
    Write-Success "系统要求检查通过 / System requirements check passed"
}

# Build project
function Build-Project {
    Write-Step "构建 Agent Chain / Building Agent Chain..."
    
    Set-Location $ProjectRoot
    
    # Build node
    if (-not (Test-Path $NodeBinary)) {
        Write-Info "构建节点程序 / Building node binary..."
        go build -o node.exe .\cmd\node
        Write-Success "节点程序构建完成 / Node binary built"
    } else {
        Write-Info "节点程序已存在 / Node binary already exists"
    }
    
    # Build wallet
    if (-not (Test-Path $WalletBinary)) {
        Write-Info "构建钱包程序 / Building wallet binary..."
        go build -o wallet.exe .\cmd\wallet
        Write-Success "钱包程序构建完成 / Wallet binary built"
    } else {
        Write-Info "钱包程序已存在 / Wallet binary already exists"
    }
    
    Write-Success "构建完成 / Build completed"
}

# Setup node configuration
function Set-NodeConfig {
    Write-Step "配置节点 / Setting up node configuration..."
    
    # Create data directory
    if (-not (Test-Path $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    }
    
    # Create node config
    $configContent = @"
# Agent Chain Node Configuration
data_dir: "$($DataDir -replace '\\', '/')"
p2p_port: $P2PPort
rpc_port: $RPCPort
is_validator: true
enable_discovery: true

# Network settings
network:
  max_peers: 50
  min_peers: 8
  discovery_interval: 30s
  address_exchange_interval: 60s
"@
    
    $configPath = Join-Path $DataDir "config.yaml"
    $configContent | Out-File -FilePath $configPath -Encoding UTF8
    
    Write-Success "节点配置完成 / Node configuration completed"
    Write-Info "数据目录 / Data directory: $DataDir"
    Write-Info "P2P 端口 / P2P port: $P2PPort"
    Write-Info "RPC 端口 / RPC port: $RPCPort"
}

# Test if port is available
function Test-Port {
    param([int]$Port)
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    } catch {
        return $false
    }
}

# Start node
function Start-Node {
    Write-Step "启动节点并加入网络 / Starting node and joining network..."
    
    # Check if port is available
    if (-not (Test-Port $RPCPort)) {
        Write-Warning "端口 $RPCPort 已被占用 / Port $RPCPort is already in use"
        Write-Info "尝试使用下一个可用端口 / Trying next available port..."
        $script:RPCPort = $RPCPort + 1
        $script:P2PPort = $P2PPort + 1
        Set-NodeConfig
    }
    
    # Start node in background
    $logFile = Join-Path $DataDir "node.log"
    $configPath = Join-Path $DataDir "config.yaml"
    
    Write-Info "启动节点 / Starting node..."
    Write-Info "日志文件 / Log file: $logFile"
    
    $processArgs = @("--config", $configPath, "--discovery")
    $process = Start-Process -FilePath $NodeBinary -ArgumentList $processArgs -RedirectStandardOutput $logFile -RedirectStandardError $logFile -PassThru
    
    $process.Id | Out-File -FilePath (Join-Path $DataDir "node.pid") -Encoding ASCII
    
    # Wait for node to start
    Write-Info "等待节点启动 / Waiting for node to start..."
    $maxWait = 30
    $waitTime = 0
    
    while ($waitTime -lt $maxWait) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$RPCPort/health" -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Success "节点启动成功！/ Node started successfully!"
                break
            }
        } catch {
            # Continue waiting
        }
        
        Start-Sleep -Seconds 2
        $waitTime += 2
        Write-Host "`r等待中 / Waiting... ${waitTime}s" -NoNewline
    }
    Write-Host ""
    
    if ($waitTime -ge $maxWait) {
        Write-Error "节点启动超时 / Node startup timeout"
        Write-Info "请检查日志文件 / Please check log file: $logFile"
        return $false
    }
    
    # Get node info
    try {
        $nodeInfo = Invoke-RestMethod -Uri "http://localhost:$RPCPort/health" -ErrorAction Stop
        $nodeId = if ($nodeInfo.node_id) { $nodeInfo.node_id.Substring(0, 20) + "..." } else { "unknown" }
        $height = if ($nodeInfo.height) { $nodeInfo.height } else { "0" }
        
        Write-Success "节点信息 / Node information:"
        Write-Host "  • 节点ID / Node ID: $nodeId"
        Write-Host "  • 当前高度 / Current height: $height"
        Write-Host "  • RPC端点 / RPC endpoint: http://localhost:$RPCPort"
        Write-Host "  • 进程ID / Process ID: $($process.Id)"
    } catch {
        Write-Warning "无法获取节点信息 / Cannot get node information"
    }
    
    return $true
}

# Create wallet
function New-Wallet {
    Write-Step "创建钱包 / Creating wallet..."
    
    $walletName = "default"
    $walletDataDir = Join-Path $DataDir "wallet"
    
    # Create wallet data directory
    if (-not (Test-Path $walletDataDir)) {
        New-Item -ItemType Directory -Path $walletDataDir -Force | Out-Null
    }
    
    # Check if wallet already exists
    try {
        $existingWallets = & $WalletBinary list --data-dir $walletDataDir 2>$null
        if ($existingWallets -match $walletName) {
            Write-Info "钱包已存在 / Wallet already exists"
        } else {
            throw "Wallet not found"
        }
    } catch {
        Write-Info "创建新钱包 / Creating new wallet..."
        & $WalletBinary new --name $walletName --data-dir $walletDataDir
        Write-Success "钱包创建完成 / Wallet created successfully"
    }
    
    # Get wallet address
    try {
        $walletList = & $WalletBinary list --data-dir $walletDataDir
        $address = ($walletList | Select-String $walletName | ForEach-Object { $_.Line.Split()[1] })
        if (-not $address) { $address = "unknown" }
    } catch {
        $address = "unknown"
    }
    
    Write-Success "钱包信息 / Wallet information:"
    Write-Host "  • 钱包名称 / Wallet name: $walletName"
    Write-Host "  • 钱包地址 / Wallet address: $address"
    Write-Host "  • 数据目录 / Data directory: $walletDataDir"
    
    # Save wallet info
    $walletInfo = @"
# Agent Chain Wallet Information
Wallet Name: $walletName
Wallet Address: $address
Data Directory: $walletDataDir
RPC Endpoint: http://localhost:$RPCPort
"@
    $walletInfo | Out-File -FilePath (Join-Path $DataDir "wallet-info.txt") -Encoding UTF8
}

# Check network status
function Test-NetworkStatus {
    Write-Step "检查网络状态 / Checking network status..."
    
    try {
        $nodeInfo = Invoke-RestMethod -Uri "http://localhost:$RPCPort/health" -ErrorAction Stop
        $height = if ($nodeInfo.height) { $nodeInfo.height } else { "0" }
        $peers = if ($nodeInfo.peers) { $nodeInfo.peers } else { "0" }
        $status = if ($nodeInfo.status) { $nodeInfo.status } else { "unknown" }
        
        Write-Success "网络状态 / Network status:"
        Write-Host "  • 区块高度 / Block height: $height"
        Write-Host "  • 连接节点 / Connected peers: $peers"
        Write-Host "  • 节点状态 / Node status: $status"
        
        if ($status -eq "ok") {
            Write-Success "✅ 成功加入 Agent Chain 网络！"
            Write-Success "✅ Successfully joined Agent Chain network!"
        } else {
            Write-Warning "⚠️ 节点正在同步中 / Node is syncing..."
        }
    } catch {
        Write-Warning "无法获取网络状态 / Cannot get network status"
    }
}

# Show usage instructions
function Show-UsageInstructions {
    Write-Step "使用说明 / Usage instructions..."
    
    Write-Host ""
    Write-Host "🎉 恭喜！您已成功加入 Agent Chain 网络！" -ForegroundColor Green
    Write-Host "🎉 Congratulations! You have successfully joined the Agent Chain network!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 常用命令 / Common commands:"
    Write-Host ""
    Write-Host "💰 钱包操作 / Wallet operations:"
    Write-Host "  # 查看余额 / Check balance"
    Write-Host "  .\wallet.exe balance --account default --data-dir `"$DataDir\wallet`" --rpc http://localhost:$RPCPort"
    Write-Host ""
    Write-Host "  # 查看区块高度 / Check block height"
    Write-Host "  .\wallet.exe height --rpc http://localhost:$RPCPort"
    Write-Host ""
    Write-Host "🔧 节点管理 / Node management:"
    Write-Host "  # 查看节点状态 / Check node status"
    Write-Host "  Invoke-RestMethod http://localhost:$RPCPort/health"
    Write-Host ""
    Write-Host "  # 查看日志 / View logs"
    Write-Host "  Get-Content `"$DataDir\node.log`" -Tail 20 -Wait"
    Write-Host ""
    Write-Host "📁 重要文件 / Important files:"
    Write-Host "  • 节点配置 / Node config: $DataDir\config.yaml"
    Write-Host "  • 钱包信息 / Wallet info: $DataDir\wallet-info.txt"
    Write-Host "  • 节点日志 / Node logs: $DataDir\node.log"
    Write-Host "  • 进程ID / Process ID: $DataDir\node.pid"
    Write-Host ""
}

# Create management script
function New-ManagementScript {
    Write-Step "创建管理脚本 / Creating management script..."
    
    $managementScript = @"
# Agent Chain Node Management Script for Windows

param([string]`$Action = "help")

`$DataDir = "`$PSScriptRoot"
`$ProjectRoot = Split-Path (Split-Path `$DataDir)
`$NodeBinary = Join-Path `$ProjectRoot "node.exe"
`$WalletBinary = Join-Path `$ProjectRoot "wallet.exe"
`$ConfigPath = Join-Path `$DataDir "config.yaml"
`$PidFile = Join-Path `$DataDir "node.pid"
`$LogFile = Join-Path `$DataDir "node.log"

# Get RPC port from config
`$RPCPort = (Get-Content `$ConfigPath | Select-String "rpc_port:" | ForEach-Object { `$_.Line.Split(":")[1].Trim() })

switch (`$Action) {
    "start" {
        Write-Host "Starting node..."
        `$process = Start-Process -FilePath `$NodeBinary -ArgumentList @("--config", `$ConfigPath, "--discovery") -RedirectStandardOutput `$LogFile -RedirectStandardError `$LogFile -PassThru
        `$process.Id | Out-File -FilePath `$PidFile -Encoding ASCII
        Write-Host "Node started. PID: `$(`$process.Id)"
    }
    "stop" {
        if (Test-Path `$PidFile) {
            `$pid = Get-Content `$PidFile
            try {
                Stop-Process -Id `$pid -Force
                Remove-Item `$PidFile
                Write-Host "Node stopped."
            } catch {
                Write-Host "Failed to stop node or node not running."
            }
        } else {
            Write-Host "Node is not running."
        }
    }
    "status" {
        if (Test-Path `$PidFile) {
            `$pid = Get-Content `$PidFile
            if (Get-Process -Id `$pid -ErrorAction SilentlyContinue) {
                Write-Host "Node is running. PID: `$pid"
                try {
                    Invoke-RestMethod "http://localhost:`$RPCPort/health" | ConvertTo-Json
                } catch {
                    Write-Host "RPC not responding"
                }
            } else {
                Write-Host "Node is not running."
            }
        } else {
            Write-Host "Node is not running."
        }
    }
    "logs" {
        Get-Content `$LogFile -Tail 20 -Wait
    }
    "wallet" {
        `$walletArgs = `$args[1..`$args.Length]
        & `$WalletBinary `$walletArgs --data-dir "`$DataDir\wallet" --rpc "http://localhost:`$RPCPort"
    }
    default {
        Write-Host "Usage: .\manage-node.ps1 {start|stop|status|logs|wallet}"
        Write-Host "  start   - Start the node"
        Write-Host "  stop    - Stop the node"
        Write-Host "  status  - Show node status"
        Write-Host "  logs    - Show node logs"
        Write-Host "  wallet  - Run wallet commands"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  .\manage-node.ps1 start"
        Write-Host "  .\manage-node.ps1 wallet balance --account default"
        Write-Host "  .\manage-node.ps1 wallet height"
    }
}
"@
    
    $managementScriptPath = Join-Path $DataDir "manage-node.ps1"
    $managementScript | Out-File -FilePath $managementScriptPath -Encoding UTF8
    Write-Success "管理脚本创建完成 / Management script created: $managementScriptPath"
}

# Main function
function Main {
    if ($Help) {
        Show-Help
    }
    
    Show-Welcome
    
    Write-Info "节点名称 / Node name: $NodeName"
    Write-Info "P2P 端口 / P2P port: $P2PPort"
    Write-Info "RPC 端口 / RPC port: $RPCPort"
    Write-Host ""
    
    # Execute steps
    Test-Requirements
    Build-Project
    Set-NodeConfig
    
    if (Start-Node) {
        New-Wallet
        Test-NetworkStatus
        New-ManagementScript
        Show-UsageInstructions
        
        Write-Host ""
        Write-Success "🎉 Agent Chain 节点部署完成！"
        Write-Success "🎉 Agent Chain node deployment completed!"
        Write-Host ""
        Write-Info "您的节点正在运行并已加入网络。"
        Write-Info "Your node is running and has joined the network."
        Write-Host ""
        Write-Info "使用管理脚本 / Use management script:"
        Write-Info "  $DataDir\manage-node.ps1 status"
        Write-Info "  $DataDir\manage-node.ps1 wallet balance --account default"
        Write-Host ""
    } else {
        Write-Error "节点启动失败 / Node startup failed"
        exit 1
    }
}

# Run main function
Main
