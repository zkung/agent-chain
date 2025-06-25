package network

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/libp2p/go-libp2p"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/protocol"
	"github.com/multiformats/go-multiaddr"
	"github.com/sirupsen/logrus"

	"agent-chain/pkg/types"
)

const (
	ProtocolID = "/agent-chain/1.0.0"
)

// Message types
const (
	MsgTypeBlock       = "block"
	MsgTypeTransaction = "transaction"
	MsgTypeGetBlocks   = "get_blocks"
	MsgTypeGetHeight   = "get_height"
	MsgTypeHeight      = "height"
)

// Message represents a network message
type Message struct {
	Type      string      `json:"type"`
	Data      interface{} `json:"data"`
	Timestamp int64       `json:"timestamp"`
	From      string      `json:"from"`
}

// Network handles P2P networking
type Network struct {
	host       host.Host
	ctx        context.Context
	cancel     context.CancelFunc
	peers      map[peer.ID]*types.NodeInfo
	peersMu    sync.RWMutex
	handlers   map[string]MessageHandler
	handlersMu sync.RWMutex
	logger     *logrus.Logger
	discovery  *PeerDiscovery
}

// MessageHandler handles incoming messages
type MessageHandler func(msg *Message, from peer.ID) error

// NewNetwork creates a new network instance
func NewNetwork(port int, logger *logrus.Logger) (*Network, error) {
	ctx, cancel := context.WithCancel(context.Background())

	// Create libp2p host
	h, err := libp2p.New(
		libp2p.ListenAddrStrings(fmt.Sprintf("/ip4/0.0.0.0/tcp/%d", port)),
		libp2p.Ping(false),
	)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create libp2p host: %v", err)
	}

	n := &Network{
		host:     h,
		ctx:      ctx,
		cancel:   cancel,
		peers:    make(map[peer.ID]*types.NodeInfo),
		handlers: make(map[string]MessageHandler),
		logger:   logger,
	}

	// Set stream handler
	h.SetStreamHandler(protocol.ID(ProtocolID), n.handleStream)

	// Initialize peer discovery
	n.discovery = NewPeerDiscovery(n, false, logger)

	return n, nil
}

// Start starts the network
func (n *Network) Start() error {
	n.logger.Infof("Network started on %s", n.host.Addrs())

	// Start peer discovery
	if err := n.discovery.Start(); err != nil {
		return fmt.Errorf("failed to start peer discovery: %v", err)
	}

	return nil
}

// Stop stops the network
func (n *Network) Stop() error {
	n.cancel()
	return n.host.Close()
}

// GetID returns the host ID
func (n *Network) GetID() string {
	return n.host.ID().String()
}

// GetAddresses returns host addresses
func (n *Network) GetAddresses() []string {
	addrs := make([]string, len(n.host.Addrs()))
	for i, addr := range n.host.Addrs() {
		addrs[i] = addr.String()
	}
	return addrs
}

// ConnectToPeer connects to a peer
func (n *Network) ConnectToPeer(addr string) error {
	maddr, err := multiaddr.NewMultiaddr(addr)
	if err != nil {
		return fmt.Errorf("invalid multiaddr: %v", err)
	}

	info, err := peer.AddrInfoFromP2pAddr(maddr)
	if err != nil {
		return fmt.Errorf("failed to get peer info: %v", err)
	}

	ctx, cancel := context.WithTimeout(n.ctx, 10*time.Second)
	defer cancel()

	if err := n.host.Connect(ctx, *info); err != nil {
		return fmt.Errorf("failed to connect to peer: %v", err)
	}

	n.peersMu.Lock()
	n.peers[info.ID] = &types.NodeInfo{
		ID:       info.ID.String(),
		LastSeen: time.Now(),
	}
	n.peersMu.Unlock()

	n.logger.Infof("Connected to peer: %s", info.ID)
	return nil
}

// RegisterHandler registers a message handler
func (n *Network) RegisterHandler(msgType string, handler MessageHandler) {
	n.handlersMu.Lock()
	defer n.handlersMu.Unlock()
	n.handlers[msgType] = handler
}

// Broadcast sends a message to all connected peers
func (n *Network) Broadcast(msgType string, data interface{}) error {
	msg := &Message{
		Type:      msgType,
		Data:      data,
		Timestamp: time.Now().Unix(),
		From:      n.host.ID().String(),
	}

	msgData, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %v", err)
	}

	n.peersMu.RLock()
	peers := make([]peer.ID, 0, len(n.peers))
	for peerID := range n.peers {
		peers = append(peers, peerID)
	}
	n.peersMu.RUnlock()

	for _, peerID := range peers {
		go func(pid peer.ID) {
			if err := n.sendToPeer(pid, msgData); err != nil {
				n.logger.Errorf("Failed to send message to peer %s: %v", pid, err)
			}
		}(peerID)
	}

	return nil
}

// SendToPeer sends a message to a specific peer
func (n *Network) SendToPeer(peerID string, msgType string, data interface{}) error {
	pid, err := peer.Decode(peerID)
	if err != nil {
		return fmt.Errorf("invalid peer ID: %v", err)
	}

	msg := &Message{
		Type:      msgType,
		Data:      data,
		Timestamp: time.Now().Unix(),
		From:      n.host.ID().String(),
	}

	msgData, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %v", err)
	}

	return n.sendToPeer(pid, msgData)
}

// sendToPeer sends raw data to a peer
func (n *Network) sendToPeer(peerID peer.ID, data []byte) error {
	ctx, cancel := context.WithTimeout(n.ctx, 10*time.Second)
	defer cancel()

	stream, err := n.host.NewStream(ctx, peerID, protocol.ID(ProtocolID))
	if err != nil {
		return fmt.Errorf("failed to create stream: %v", err)
	}
	defer stream.Close()

	if _, err := stream.Write(data); err != nil {
		return fmt.Errorf("failed to write to stream: %v", err)
	}

	return nil
}

// handleStream handles incoming streams
func (n *Network) handleStream(stream network.Stream) {
	defer stream.Close()

	buf := make([]byte, 4096)
	bytesRead, err := stream.Read(buf)
	if err != nil {
		n.logger.Errorf("Failed to read from stream: %v", err)
		return
	}

	var msg Message
	if err := json.Unmarshal(buf[:bytesRead], &msg); err != nil {
		n.logger.Errorf("Failed to unmarshal message: %v", err)
		return
	}

	// Update peer info
	peerID := stream.Conn().RemotePeer()
	n.peersMu.Lock()
	if _, exists := n.peers[peerID]; !exists {
		n.peers[peerID] = &types.NodeInfo{
			ID: peerID.String(),
		}
	}
	n.peers[peerID].LastSeen = time.Now()
	n.peersMu.Unlock()

	// Handle message
	n.handlersMu.RLock()
	handler, exists := n.handlers[msg.Type]
	n.handlersMu.RUnlock()

	if exists {
		if err := handler(&msg, peerID); err != nil {
			n.logger.Errorf("Handler error for message type %s: %v", msg.Type, err)
		}
	} else {
		n.logger.Warnf("No handler for message type: %s", msg.Type)
	}
}

// GetPeers returns connected peers
func (n *Network) GetPeers() []*types.NodeInfo {
	n.peersMu.RLock()
	defer n.peersMu.RUnlock()

	peers := make([]*types.NodeInfo, 0, len(n.peers))
	for _, peer := range n.peers {
		peers = append(peers, peer)
	}
	return peers
}

// GetPeerCount returns the number of connected peers
func (n *Network) GetPeerCount() int {
	n.peersMu.RLock()
	defer n.peersMu.RUnlock()
	return len(n.peers)
}

// RequestHeight requests height from a peer
func (n *Network) RequestHeight(peerID string) error {
	return n.SendToPeer(peerID, MsgTypeGetHeight, nil)
}

// RequestBlocks requests blocks from a peer
func (n *Network) RequestBlocks(peerID string, fromHeight int64) error {
	return n.SendToPeer(peerID, MsgTypeGetBlocks, map[string]interface{}{
		"from_height": fromHeight,
	})
}

// ConnectToPeerByMultiaddr connects to a peer using multiaddr
func (n *Network) ConnectToPeerByMultiaddr(maddr multiaddr.Multiaddr) error {
	// Extract peer info from multiaddr
	info, err := peer.AddrInfoFromP2pAddr(maddr)
	if err != nil {
		return fmt.Errorf("failed to get peer info: %v", err)
	}

	// Connect to peer
	ctx, cancel := context.WithTimeout(n.ctx, 30*time.Second)
	defer cancel()

	err = n.host.Connect(ctx, *info)
	if err != nil {
		return fmt.Errorf("failed to connect to peer: %v", err)
	}

	n.logger.Infof("Connected to peer %s", info.ID)
	return nil
}

// IsConnected checks if we're connected to a specific address
func (n *Network) IsConnected(address string) bool {
	// Simple check - in a real implementation, you'd parse the address
	// and check against connected peers
	return false
}

// GetConnectedPeers returns list of connected peer IDs
func (n *Network) GetConnectedPeers() []peer.ID {
	n.peersMu.RLock()
	defer n.peersMu.RUnlock()

	var peers []peer.ID
	for peerID := range n.peers {
		peers = append(peers, peerID)
	}
	return peers
}



// EnableBootstrapMode enables bootstrap mode for this node
func (n *Network) EnableBootstrapMode() {
	if n.discovery != nil {
		n.discovery.isBootstrap = true
		n.logger.Info("Bootstrap mode enabled - this node will help other nodes discover the network")
	}
}

// GetDiscoveryStats returns peer discovery statistics
func (n *Network) GetDiscoveryStats() map[string]interface{} {
	if n.discovery != nil {
		return n.discovery.GetStats()
	}
	return map[string]interface{}{
		"discovery_enabled": false,
	}
}
