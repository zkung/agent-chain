package network

import (
	"context"
	"fmt"
	"net"
	"strings"
	"sync"
	"time"
	"math/rand"

	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/multiformats/go-multiaddr"
	"github.com/sirupsen/logrus"
)

// DNS种子节点 - 类似比特币的DNS种子
var DNSSeeds = []string{
	"seed.agentchain.io",
	"nodes.agentchain.io", 
	"bootstrap.agentchain.io",
	"peers.agentchain.io",
}

// 硬编码种子节点 - 类似比特币的硬编码节点
var HardcodedSeeds = []string{
	"127.0.0.1:9001",  // 本地测试节点
	"127.0.0.1:9002",  // 本地测试节点2
	"127.0.0.1:9003",  // 本地测试节点3
	// 在实际部署中，这里会是真实的公网节点地址
}

// 网络常量
const (
	MaxPeers              = 50
	MinPeers              = 8
	DiscoveryInterval     = 30 * time.Second
	PeerExchangeInterval  = 60 * time.Second
	MaxAddressAge         = 24 * time.Hour
	AddressExchangeCount  = 100
)

// PeerDiscovery 处理节点发现和连接管理
type PeerDiscovery struct {
	network     *Network
	ctx         context.Context
	cancel      context.CancelFunc
	knownAddrs  map[string]*AddressInfo
	addrsMu     sync.RWMutex
	logger      *logrus.Logger
	isBootstrap bool
}

// AddressInfo 存储节点地址信息
type AddressInfo struct {
	Address   string
	LastSeen  time.Time
	Quality   int
	Attempts  int
	Success   int
}

// AddressMessage P2P地址交换消息
type AddressMessage struct {
	Addresses []string `json:"addresses"`
	Timestamp int64    `json:"timestamp"`
}

// NewPeerDiscovery 创建新的节点发现实例
func NewPeerDiscovery(network *Network, isBootstrap bool, logger *logrus.Logger) *PeerDiscovery {
	ctx, cancel := context.WithCancel(context.Background())
	
	pd := &PeerDiscovery{
		network:     network,
		ctx:         ctx,
		cancel:      cancel,
		knownAddrs:  make(map[string]*AddressInfo),
		logger:      logger,
		isBootstrap: isBootstrap,
	}
	
	// 注册地址交换消息处理器
	network.RegisterHandler("addr", pd.handleAddressMessage)
	network.RegisterHandler("getaddr", pd.handleGetAddressMessage)
	
	return pd
}

// Start 启动节点发现
func (pd *PeerDiscovery) Start() error {
	pd.logger.Info("Starting peer discovery...")
	
	// 初始化种子节点
	pd.initializeSeedNodes()
	
	// 启动发现循环
	go pd.discoveryLoop()
	
	// 启动地址交换循环
	go pd.addressExchangeLoop()
	
	// 启动连接维护循环
	go pd.connectionMaintenanceLoop()
	
	return nil
}

// Stop 停止节点发现
func (pd *PeerDiscovery) Stop() error {
	pd.cancel()
	return nil
}

// initializeSeedNodes 初始化种子节点
func (pd *PeerDiscovery) initializeSeedNodes() {
	// 1. 从DNS种子发现节点
	dnsAddrs := pd.discoverFromDNS()
	for _, addr := range dnsAddrs {
		pd.addKnownAddress(addr)
	}
	
	// 2. 添加硬编码种子节点
	for _, addr := range HardcodedSeeds {
		pd.addKnownAddress(addr)
	}
	
	pd.logger.Infof("Initialized with %d seed addresses", len(pd.knownAddrs))
}

// discoverFromDNS 从DNS种子发现节点
func (pd *PeerDiscovery) discoverFromDNS() []string {
	var addresses []string
	
	for _, seed := range DNSSeeds {
		ips, err := net.LookupHost(seed)
		if err != nil {
			pd.logger.Debugf("Failed to resolve DNS seed %s: %v", seed, err)
			continue
		}
		
		for _, ip := range ips {
			// 默认使用9001端口
			addr := fmt.Sprintf("%s:9001", ip)
			addresses = append(addresses, addr)
		}
	}
	
	pd.logger.Infof("Discovered %d addresses from DNS seeds", len(addresses))
	return addresses
}

// addKnownAddress 添加已知地址
func (pd *PeerDiscovery) addKnownAddress(address string) {
	pd.addrsMu.Lock()
	defer pd.addrsMu.Unlock()
	
	if _, exists := pd.knownAddrs[address]; !exists {
		pd.knownAddrs[address] = &AddressInfo{
			Address:  address,
			LastSeen: time.Now(),
			Quality:  50, // 初始质量分数
		}
	}
}

// discoveryLoop 发现循环
func (pd *PeerDiscovery) discoveryLoop() {
	ticker := time.NewTicker(DiscoveryInterval)
	defer ticker.Stop()
	
	for {
		select {
		case <-pd.ctx.Done():
			return
		case <-ticker.C:
			pd.discoverAndConnect()
		}
	}
}

// discoverAndConnect 发现并连接节点
func (pd *PeerDiscovery) discoverAndConnect() {
	currentPeers := pd.network.GetPeerCount()
	
	if currentPeers >= MaxPeers {
		return
	}
	
	needed := MinPeers - currentPeers
	if needed <= 0 {
		return
	}
	
	// 获取候选地址
	candidates := pd.getCandidateAddresses(needed * 2)
	
	// 尝试连接
	for _, addr := range candidates {
		if currentPeers >= MaxPeers {
			break
		}
		
		if pd.attemptConnection(addr) {
			currentPeers++
		}
	}
}

// getCandidateAddresses 获取候选地址
func (pd *PeerDiscovery) getCandidateAddresses(count int) []string {
	pd.addrsMu.RLock()
	defer pd.addrsMu.RUnlock()
	
	var candidates []string
	var addresses []*AddressInfo
	
	// 收集所有地址
	for _, info := range pd.knownAddrs {
		// 跳过已连接的节点
		if pd.network.IsConnected(info.Address) {
			continue
		}
		
		// 跳过质量太低的地址
		if info.Quality < 10 {
			continue
		}
		
		addresses = append(addresses, info)
	}
	
	// 按质量排序并随机化
	rand.Shuffle(len(addresses), func(i, j int) {
		addresses[i], addresses[j] = addresses[j], addresses[i]
	})
	
	// 选择前N个
	for i, addr := range addresses {
		if i >= count {
			break
		}
		candidates = append(candidates, addr.Address)
	}
	
	return candidates
}

// attemptConnection 尝试连接到节点
func (pd *PeerDiscovery) attemptConnection(address string) bool {
	pd.addrsMu.Lock()
	info := pd.knownAddrs[address]
	if info != nil {
		info.Attempts++
	}
	pd.addrsMu.Unlock()
	
	// 解析地址
	maddr, err := pd.parseAddress(address)
	if err != nil {
		pd.logger.Debugf("Failed to parse address %s: %v", address, err)
		return false
	}
	
	// 尝试连接
	err = pd.network.ConnectToPeerByMultiaddr(maddr)
	if err != nil {
		pd.logger.Debugf("Failed to connect to %s: %v", address, err)
		pd.updateAddressQuality(address, false)
		return false
	}
	
	pd.logger.Infof("Successfully connected to %s", address)
	pd.updateAddressQuality(address, true)
	return true
}

// parseAddress 解析地址为multiaddr
func (pd *PeerDiscovery) parseAddress(address string) (multiaddr.Multiaddr, error) {
	// 简单的TCP地址解析
	parts := strings.Split(address, ":")
	if len(parts) != 2 {
		return nil, fmt.Errorf("invalid address format: %s", address)
	}
	
	return multiaddr.NewMultiaddr(fmt.Sprintf("/ip4/%s/tcp/%s", parts[0], parts[1]))
}

// updateAddressQuality 更新地址质量
func (pd *PeerDiscovery) updateAddressQuality(address string, success bool) {
	pd.addrsMu.Lock()
	defer pd.addrsMu.Unlock()
	
	info := pd.knownAddrs[address]
	if info == nil {
		return
	}
	
	if success {
		info.Success++
		info.Quality += 10
		if info.Quality > 100 {
			info.Quality = 100
		}
	} else {
		info.Quality -= 5
		if info.Quality < 0 {
			info.Quality = 0
		}
	}
	
	info.LastSeen = time.Now()
}

// addressExchangeLoop 地址交换循环
func (pd *PeerDiscovery) addressExchangeLoop() {
	ticker := time.NewTicker(PeerExchangeInterval)
	defer ticker.Stop()
	
	for {
		select {
		case <-pd.ctx.Done():
			return
		case <-ticker.C:
			pd.exchangeAddresses()
		}
	}
}

// exchangeAddresses 与连接的节点交换地址
func (pd *PeerDiscovery) exchangeAddresses() {
	peers := pd.network.GetConnectedPeers()
	
	for _, peerID := range peers {
		// 请求对方的地址列表
		msg := &Message{
			Type:      "getaddr",
			Data:      nil,
			Timestamp: time.Now().Unix(),
		}
		
		pd.network.SendToPeer(peerID.String(), msg.Type, msg.Data)
	}
}

// handleGetAddressMessage 处理地址请求消息
func (pd *PeerDiscovery) handleGetAddressMessage(msg *Message, from peer.ID) error {
	// 发送我们知道的地址
	addresses := pd.getRandomAddresses(AddressExchangeCount)
	
	response := &Message{
		Type: "addr",
		Data: AddressMessage{
			Addresses: addresses,
			Timestamp: time.Now().Unix(),
		},
		Timestamp: time.Now().Unix(),
	}
	
	return pd.network.SendToPeer(from.String(), response.Type, response.Data)
}

// handleAddressMessage 处理地址消息
func (pd *PeerDiscovery) handleAddressMessage(msg *Message, from peer.ID) error {
	var addrMsg AddressMessage
	
	// 解析消息数据
	if data, ok := msg.Data.(map[string]interface{}); ok {
		if addresses, ok := data["addresses"].([]interface{}); ok {
			for _, addr := range addresses {
				if addrStr, ok := addr.(string); ok {
					addrMsg.Addresses = append(addrMsg.Addresses, addrStr)
				}
			}
		}
	}
	
	// 添加新地址
	for _, addr := range addrMsg.Addresses {
		if pd.isValidAddress(addr) {
			pd.addKnownAddress(addr)
		}
	}
	
	pd.logger.Debugf("Received %d addresses from %s", len(addrMsg.Addresses), from)
	return nil
}

// getRandomAddresses 获取随机地址列表
func (pd *PeerDiscovery) getRandomAddresses(count int) []string {
	pd.addrsMu.RLock()
	defer pd.addrsMu.RUnlock()
	
	var addresses []string
	for addr, info := range pd.knownAddrs {
		// 只分享质量较好的地址
		if info.Quality > 30 {
			addresses = append(addresses, addr)
		}
	}
	
	// 随机化
	rand.Shuffle(len(addresses), func(i, j int) {
		addresses[i], addresses[j] = addresses[j], addresses[i]
	})
	
	// 限制数量
	if len(addresses) > count {
		addresses = addresses[:count]
	}
	
	return addresses
}

// isValidAddress 验证地址有效性
func (pd *PeerDiscovery) isValidAddress(address string) bool {
	// 基本格式检查
	parts := strings.Split(address, ":")
	if len(parts) != 2 {
		return false
	}
	
	// IP地址检查
	ip := net.ParseIP(parts[0])
	if ip == nil {
		return false
	}
	
	// 端口检查
	if parts[1] == "" {
		return false
	}
	
	return true
}

// connectionMaintenanceLoop 连接维护循环
func (pd *PeerDiscovery) connectionMaintenanceLoop() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-pd.ctx.Done():
			return
		case <-ticker.C:
			pd.maintainConnections()
		}
	}
}

// maintainConnections 维护连接
func (pd *PeerDiscovery) maintainConnections() {
	currentPeers := pd.network.GetPeerCount()
	
	// 如果连接数不足，尝试连接更多节点
	if currentPeers < MinPeers {
		pd.discoverAndConnect()
	}
	
	// 清理过期地址
	pd.cleanupOldAddresses()
}

// cleanupOldAddresses 清理过期地址
func (pd *PeerDiscovery) cleanupOldAddresses() {
	pd.addrsMu.Lock()
	defer pd.addrsMu.Unlock()
	
	now := time.Now()
	for addr, info := range pd.knownAddrs {
		// 删除过期且质量低的地址
		if now.Sub(info.LastSeen) > MaxAddressAge && info.Quality < 20 {
			delete(pd.knownAddrs, addr)
		}
	}
}

// GetStats 获取发现统计信息
func (pd *PeerDiscovery) GetStats() map[string]interface{} {
	pd.addrsMu.RLock()
	defer pd.addrsMu.RUnlock()
	
	return map[string]interface{}{
		"known_addresses": len(pd.knownAddrs),
		"connected_peers": pd.network.GetPeerCount(),
		"is_bootstrap":    pd.isBootstrap,
	}
}
