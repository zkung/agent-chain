# Check P2P Network Status
Write-Host "🔍 Agent Chain P2P Network Status Check" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

$nodes = @(
    @{ Name = "Node 1 (Bootstrap)"; Port = 8545; P2PPort = 9001 },
    @{ Name = "Node 2"; Port = 8546; P2PPort = 9002 },
    @{ Name = "Node 3"; Port = 8547; P2PPort = 9003 }
)

$totalPeers = 0
$healthyNodes = 0

foreach ($node in $nodes) {
    Write-Host "`n📡 $($node.Name)" -ForegroundColor Yellow
    Write-Host "   RPC Port: $($node.Port), P2P Port: $($node.P2PPort)"
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$($node.Port)/health" -TimeoutSec 5
        
        Write-Host "   ✅ Status: $($response.status)" -ForegroundColor Green
        Write-Host "   🆔 Node ID: $($response.node_id)" -ForegroundColor White
        Write-Host "   📊 Height: $($response.height)" -ForegroundColor White
        Write-Host "   🤝 Connected Peers: $($response.peers)" -ForegroundColor $(if ($response.peers -gt 0) { "Green" } else { "Red" })
        
        $totalPeers += $response.peers
        $healthyNodes++
        
    } catch {
        Write-Host "   ❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "📈 Network Summary:" -ForegroundColor Cyan
Write-Host "   Healthy Nodes: $healthyNodes/3" -ForegroundColor $(if ($healthyNodes -eq 3) { "Green" } else { "Red" })
Write-Host "   Total P2P Connections: $totalPeers" -ForegroundColor $(if ($totalPeers -gt 0) { "Green" } else { "Red" })

if ($healthyNodes -eq 3 -and $totalPeers -gt 0) {
    Write-Host "`n🎉 P2P Network Discovery is working correctly!" -ForegroundColor Green
    Write-Host "   ✅ All nodes are healthy and connected" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  P2P Network has issues:" -ForegroundColor Yellow
    if ($healthyNodes -lt 3) {
        Write-Host "   - Some nodes are not healthy" -ForegroundColor Red
    }
    if ($totalPeers -eq 0) {
        Write-Host "   - No P2P connections established" -ForegroundColor Red
    }
}

Write-Host "`n🔧 To view detailed logs:" -ForegroundColor Cyan
Write-Host "   Get-Content logs\node1.err -Wait" -ForegroundColor White
Write-Host "   Get-Content logs\node2.err -Wait" -ForegroundColor White
Write-Host "   Get-Content logs\node3.err -Wait" -ForegroundColor White
