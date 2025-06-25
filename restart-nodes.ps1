# Restart specific nodes with updated configuration
param(
    [string[]]$Nodes = @("2", "3")
)

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Restarting nodes: $($Nodes -join ', ')" -ForegroundColor Green

foreach ($nodeNum in $Nodes) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Stopping node $nodeNum..." -ForegroundColor Yellow
    
    # Find and kill the node process
    $port = switch ($nodeNum) {
        "1" { 8545 }
        "2" { 8546 }
        "3" { 8547 }
    }
    
    $processes = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | ForEach-Object {
        Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    }
    
    foreach ($proc in $processes) {
        if ($proc.ProcessName -like "*node*" -or $proc.ProcessName -like "*go*") {
            Write-Host "Killing process $($proc.Id) ($($proc.ProcessName))"
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }
    
    Start-Sleep -Seconds 2
    
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting node $nodeNum..." -ForegroundColor Yellow
    
    # Start the node with updated config
    $configFile = "configs/node$nodeNum.yaml"
    $logFile = "logs/node$nodeNum.log"
    $errFile = "logs/node$nodeNum.err"
    
    Start-Process -FilePath "go" -ArgumentList "run", "cmd/node/main.go", "--config", $configFile -RedirectStandardOutput $logFile -RedirectStandardError $errFile -NoNewWindow
    
    Start-Sleep -Seconds 3
    
    # Check if node is healthy
    $rpcPort = switch ($nodeNum) {
        "1" { 8545 }
        "2" { 8546 }
        "3" { 8547 }
    }
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$rpcPort/health" -TimeoutSec 5
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ✅ Node $nodeNum is healthy (Height: $($response.height), Peers: $($response.peers))" -ForegroundColor Green
    } catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ❌ Node $nodeNum health check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Node restart completed!" -ForegroundColor Green
