# Agent Chain P2P Auto-Discovery Script (PowerShell)
# Automatically discovers P2P nodes and updates configuration files

param(
    [string]$ConfigPath = "configs",
    [string]$LogPath = "logs",
    [int]$ScanPortStart = 8545,
    [int]$ScanPortEnd = 8550,
    [string]$TargetNode = "",
    [switch]$DryRun = $false,
    [switch]$Verbose = $false
)

# Colors for output
$Colors = @{
    Info = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    P2P = "Magenta"
}

# Logging functions
function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = $Colors[$Level]
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-P2P {
    param([string]$Message)
    Write-Log $Message "P2P"
}

# Discover active P2P nodes
function Find-P2PNodes {
    Write-P2P "🔍 Scanning for active P2P nodes..."
    
    $discoveredNodes = @()
    
    for ($port = $ScanPortStart; $port -le $ScanPortEnd; $port++) {
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:$port/health" -TimeoutSec 3 -ErrorAction Stop
            
            if ($response.node_id -and $response.status -eq "ok") {
                # Calculate P2P port based on RPC port mapping
                $p2pPort = switch ($port) {
                    8545 { 9001 }
                    8546 { 9002 }
                    8547 { 9003 }
                    default { $port + 456 }
                }

                $nodeInfo = @{
                    RpcPort = $port
                    P2pPort = $p2pPort
                    NodeId = $response.node_id
                    Height = $response.height
                    Peers = $response.peers
                    Status = $response.status
                    IsBootstrap = ($response.peers -gt 0 -or $port -eq 8545)
                    MultiAddr = "/ip4/127.0.0.1/tcp/$p2pPort/p2p/$($response.node_id)"
                }
                
                $discoveredNodes += $nodeInfo
                
                $nodeType = if ($nodeInfo.IsBootstrap) { "Bootstrap" } else { "Node" }
                Write-Log "✅ Found $nodeType node: Port $port, ID: $($response.node_id.Substring(0,20))..., Peers: $($response.peers)" "Success"
            }
        }
        catch {
            if ($Verbose) {
                Write-Log "Port ${port}: No response" "Info"
            }
        }
    }
    
    if ($discoveredNodes.Count -eq 0) {
        Write-Log "❌ No active P2P nodes found in port range $ScanPortStart-$ScanPortEnd" "Error"
        return @()
    }
    
    Write-P2P "🎉 Discovered $($discoveredNodes.Count) active P2P nodes"
    return $discoveredNodes
}

# Get bootstrap nodes (nodes with peers or port 8545)
function Get-BootstrapNodes {
    param([array]$DiscoveredNodes)

    $bootstrapNodes = $DiscoveredNodes | Where-Object {
        $_.IsBootstrap -or $_.Peers -gt 0 -or $_.RpcPort -eq 8545
    }

    if ($bootstrapNodes.Count -eq 0) {
        # If no clear bootstrap, use the first node
        $bootstrapNodes = @($DiscoveredNodes[0])
    }

    Write-P2P "🚀 Identified $($bootstrapNodes.Count) bootstrap nodes"
    return $bootstrapNodes
}

# Read existing configuration
function Read-ConfigFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "⚠️ Config file not found: $FilePath" "Warning"
        return $null
    }
    
    try {
        $content = Get-Content $FilePath -Raw
        return $content
    }
    catch {
        Write-Log "❌ Failed to read config file: $FilePath" "Error"
        return $null
    }
}

# Update configuration file with P2P bootstrap nodes
function Update-ConfigFile {
    param(
        [string]$ConfigFile,
        [array]$BootstrapNodes,
        [hashtable]$CurrentNode
    )
    
    Write-P2P "📝 Updating configuration: $ConfigFile"
    
    $config = Read-ConfigFile $ConfigFile
    if (-not $config) {
        return $false
    }
    
    # Extract current node info from config
    $dataDir = if ($config -match 'data_dir:\s*"?([^"]+)"?') { $matches[1] } else { "data/node" }

    # Extract RPC port more carefully
    $rpcPort = 8546  # default
    if ($config -match 'rpc:[\s\S]*?port:\s*(\d+)') {
        $rpcPort = [int]$matches[1]
    }

    # Extract P2P port more carefully
    $p2pPort = 9002  # default
    if ($config -match 'p2p:[\s\S]*?port:\s*(\d+)') {
        $p2pPort = [int]$matches[1]
    }
    
    # Filter out self from bootstrap nodes
    $filteredBootstrap = $BootstrapNodes | Where-Object { $_.RpcPort -ne [int]$rpcPort }
    
    if ($filteredBootstrap.Count -eq 0) {
        Write-Log "⚠️ No suitable bootstrap nodes found (excluding self)" "Warning"
        return $false
    }
    
    # Create boot_nodes list
    $bootNodesList = $filteredBootstrap | ForEach-Object { "    - `"$($_.MultiAddr)`"" }
    $bootNodesSection = $bootNodesList -join "`n"
    
    # Create new configuration
    $newConfig = @"
data_dir: "$dataDir"
p2p:
  port: $p2pPort
  is_bootstrap: false
  enable_discovery: true
  boot_nodes:
$bootNodesSection
rpc:
  port: $rpcPort
validator:
  enabled: true
"@
    
    if ($DryRun) {
        Write-Log "🔍 DRY RUN - Would update $ConfigFile with:" "Info"
        Write-Host $newConfig -ForegroundColor Gray
        return $true
    }
    
    try {
        # Backup original config
        $backupFile = "$ConfigFile.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $ConfigFile $backupFile
        Write-Log "💾 Backup created: $backupFile" "Info"
        
        # Write new config
        $newConfig | Out-File -FilePath $ConfigFile -Encoding UTF8
        Write-Log "✅ Configuration updated successfully" "Success"
        
        # Verify the update
        $verification = Read-ConfigFile $ConfigFile
        if ($verification -match "boot_nodes:") {
            Write-Log "✅ Configuration verification passed" "Success"
            return $true
        } else {
            Write-Log "❌ Configuration verification failed" "Error"
            return $false
        }
    }
    catch {
        Write-Log "❌ Failed to update configuration: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Get configuration files to update
function Get-ConfigFiles {
    param([string]$ConfigPath, [string]$TargetNode)
    
    if ($TargetNode) {
        $configFile = Join-Path $ConfigPath "$TargetNode.yaml"
        if (Test-Path $configFile) {
            return @($configFile)
        } else {
            Write-Log "❌ Target config file not found: $configFile" "Error"
            return @()
        }
    }
    
    # Find all node config files
    $configFiles = Get-ChildItem -Path $ConfigPath -Filter "node*.yaml" | ForEach-Object { $_.FullName }
    
    if ($configFiles.Count -eq 0) {
        Write-Log "❌ No node configuration files found in: $ConfigPath" "Error"
    }
    
    return $configFiles
}

# Restart node after configuration update
function Restart-Node {
    param([string]$ConfigFile)
    
    $nodeName = [System.IO.Path]::GetFileNameWithoutExtension($ConfigFile)
    Write-P2P "🔄 Restarting $nodeName..."
    
    # Extract RPC port from config to identify the node process
    $config = Read-ConfigFile $ConfigFile
    if ($config -match 'rpc:[\s\S]*?port:\s*(\d+)') {
        $rpcPort = $matches[1]
        
        # Find and kill existing process
        $processes = Get-NetTCPConnection -LocalPort $rpcPort -ErrorAction SilentlyContinue | ForEach-Object {
            Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        }
        
        foreach ($proc in $processes) {
            if ($proc.ProcessName -like "*node*" -or $proc.ProcessName -like "*go*") {
                Write-Log "Stopping process $($proc.Id) ($($proc.ProcessName))" "Info"
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        }
        
        Start-Sleep -Seconds 2
        
        # Start the node
        $logFile = "logs/$nodeName.log"
        $errFile = "logs/$nodeName.err"
        
        Write-Log "Starting $nodeName..." "Info"
        Start-Process -FilePath "go" -ArgumentList "run", "cmd/node/main.go", "--config", $ConfigFile -RedirectStandardOutput $logFile -RedirectStandardError $errFile -NoNewWindow
        
        Start-Sleep -Seconds 5
        
        # Verify restart
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:$rpcPort/health" -TimeoutSec 5
            Write-Log "✅ $nodeName restarted successfully (Peers: $($response.peers))" "Success"
            return $true
        } catch {
            Write-Log "❌ $nodeName restart verification failed" "Error"
            return $false
        }
    }
    
    return $false
}

# Main execution
function Main {
    Write-P2P "🌐 Agent Chain P2P Auto-Discovery Tool"
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    if ($DryRun) {
        Write-Log "🔍 Running in DRY RUN mode - no changes will be made" "Warning"
    }
    
    # Discover P2P nodes
    $discoveredNodes = Find-P2PNodes
    if ($discoveredNodes.Count -eq 0) {
        exit 1
    }
    
    # Get bootstrap nodes
    $bootstrapNodes = Get-BootstrapNodes $discoveredNodes
    
    # Display discovered nodes
    Write-P2P "📊 Discovered Nodes:"
    foreach ($node in $discoveredNodes) {
        $type = if ($node.IsBootstrap) { "Bootstrap" } else { "Node" }
        Write-Host "  • $type - RPC:$($node.RpcPort), P2P:$($node.P2pPort), Peers:$($node.Peers)" -ForegroundColor White
        Write-Host "    ID: $($node.NodeId)" -ForegroundColor Gray
    }
    
    Write-P2P "🚀 Bootstrap Nodes:"
    foreach ($node in $bootstrapNodes) {
        Write-Host "  • $($node.MultiAddr)" -ForegroundColor Green
    }
    
    # Get configuration files to update
    $configFiles = Get-ConfigFiles $ConfigPath $TargetNode
    if ($configFiles.Count -eq 0) {
        exit 1
    }
    
    Write-P2P "📝 Updating Configuration Files:"
    $updateCount = 0
    $restartNodes = @()
    
    foreach ($configFile in $configFiles) {
        $fileName = Split-Path $configFile -Leaf
        Write-Host "  • $fileName" -ForegroundColor Yellow
        
        if (Update-ConfigFile $configFile $bootstrapNodes @{}) {
            $updateCount++
            $restartNodes += $configFile
        }
    }
    
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Log "📈 Summary: Updated $updateCount/$($configFiles.Count) configuration files" "Info"
    
    if (-not $DryRun -and $restartNodes.Count -gt 0) {
        Write-P2P "🔄 Restarting updated nodes..."
        foreach ($configFile in $restartNodes) {
            Restart-Node $configFile
        }
    }
    
    Write-P2P "🎉 P2P Auto-Discovery completed!"
    
    if (-not $DryRun) {
        Write-Log "💡 Check network status with: bash scripts/check-p2p-status-updated.sh" "Info"
    }
}

# Show help
if ($args -contains "--help" -or $args -contains "-h") {
    Write-Host "Agent Chain P2P Auto-Discovery Tool" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\auto-discover-p2p.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -ConfigPath <path>     Configuration directory (default: configs)"
    Write-Host "  -LogPath <path>        Log directory (default: logs)"
    Write-Host "  -ScanPortStart <port>  Start of RPC port scan range (default: 8545)"
    Write-Host "  -ScanPortEnd <port>    End of RPC port scan range (default: 8550)"
    Write-Host "  -TargetNode <name>     Update specific node config (e.g., 'node2')"
    Write-Host "  -DryRun               Show what would be changed without making changes"
    Write-Host "  -Verbose              Show detailed scanning output"
    Write-Host "  -h, --help            Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\auto-discover-p2p.ps1                    # Auto-discover and update all configs"
    Write-Host "  .\auto-discover-p2p.ps1 -TargetNode node2  # Update only node2 config"
    Write-Host "  .\auto-discover-p2p.ps1 -DryRun            # Preview changes without applying"
    exit 0
}

# Run main function
Main
