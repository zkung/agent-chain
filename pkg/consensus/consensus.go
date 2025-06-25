package consensus

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/sirupsen/logrus"

	"agent-chain/pkg/blockchain"
	"agent-chain/pkg/crypto"
	"agent-chain/pkg/network"
	"agent-chain/pkg/types"
)

// Engine represents the consensus engine
type Engine struct {
	blockchain *blockchain.Blockchain
	network    *network.Network
	keyPair    *crypto.KeyPair
	config     *types.ChainConfig
	logger     *logrus.Logger

	mu          sync.RWMutex
	isValidator bool
	isRunning   bool
	ctx         context.Context
	cancel      context.CancelFunc
}

// NewEngine creates a new consensus engine
func NewEngine(bc *blockchain.Blockchain, net *network.Network, keyPair *crypto.KeyPair, config *types.ChainConfig, logger *logrus.Logger) *Engine {
	ctx, cancel := context.WithCancel(context.Background())

	return &Engine{
		blockchain:  bc,
		network:     net,
		keyPair:     keyPair,
		config:      config,
		logger:      logger,
		isValidator: true, // For simplicity, all nodes can validate
		ctx:         ctx,
		cancel:      cancel,
	}
}

// Start starts the consensus engine
func (e *Engine) Start() error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if e.isRunning {
		return fmt.Errorf("consensus engine already running")
	}

	e.isRunning = true

	// Register network handlers
	e.network.RegisterHandler(network.MsgTypeBlock, e.handleBlock)
	e.network.RegisterHandler(network.MsgTypeTransaction, e.handleTransaction)
	e.network.RegisterHandler(network.MsgTypeGetHeight, e.handleGetHeight)
	e.network.RegisterHandler(network.MsgTypeGetBlocks, e.handleGetBlocks)

	// Start block production if validator
	if e.isValidator {
		go e.blockProductionLoop()
	}

	// Start sync loop
	go e.syncLoop()

	e.logger.Info("Consensus engine started")
	return nil
}

// Stop stops the consensus engine
func (e *Engine) Stop() error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if !e.isRunning {
		return nil
	}

	e.cancel()
	e.isRunning = false

	e.logger.Info("Consensus engine stopped")
	return nil
}

// blockProductionLoop produces new blocks
func (e *Engine) blockProductionLoop() {
	ticker := time.NewTicker(e.config.BlockTime)
	defer ticker.Stop()

	for {
		select {
		case <-e.ctx.Done():
			return
		case <-ticker.C:
			if err := e.produceBlock(); err != nil {
				e.logger.Errorf("Failed to produce block: %v", err)
			}
		}
	}
}

// produceBlock creates and broadcasts a new block
func (e *Engine) produceBlock() error {
	// Get pending transactions
	pendingTxs := e.blockchain.GetPendingTransactions()

	// Limit transactions per block
	maxTxs := e.config.MaxTxPerBlock
	if len(pendingTxs) > maxTxs {
		pendingTxs = pendingTxs[:maxTxs]
	}

	// Convert to transaction slice
	txs := make([]types.Transaction, len(pendingTxs))
	for i, tx := range pendingTxs {
		txs[i] = *tx
	}

	// Create new block
	lastBlock := e.blockchain.GetLastBlock()
	block := &types.Block{
		Header: types.BlockHeader{
			Height:     e.blockchain.GetHeight() + 1,
			PrevHash:   lastBlock.Header.Hash,
			Timestamp:  time.Now().Unix(),
			Difficulty: 1, // Simplified difficulty
			Nonce:      0,
			Validator:  e.keyPair.GetAddress(),
		},
		Txs: txs,
	}

	// Calculate block hash
	block.Header.Hash = block.CalculateHash()

	// Add block to blockchain
	if err := e.blockchain.AddBlock(block); err != nil {
		return fmt.Errorf("failed to add block: %v", err)
	}

	// Broadcast block
	if err := e.network.Broadcast(network.MsgTypeBlock, block); err != nil {
		e.logger.Errorf("Failed to broadcast block: %v", err)
	}

	e.logger.Infof("Produced block #%d with %d transactions", block.Header.Height, len(block.Txs))
	return nil
}

// syncLoop synchronizes with other nodes
func (e *Engine) syncLoop() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-e.ctx.Done():
			return
		case <-ticker.C:
			e.syncWithPeers()
		}
	}
}

// syncWithPeers synchronizes blockchain with peers
func (e *Engine) syncWithPeers() {
	peers := e.network.GetPeers()
	if len(peers) == 0 {
		return
	}

	// Request height from first peer
	if err := e.network.RequestHeight(peers[0].ID); err != nil {
		e.logger.Errorf("Failed to request height: %v", err)
	}
}

// handleBlock handles incoming block messages
func (e *Engine) handleBlock(msg *network.Message, from peer.ID) error {
	_, ok := msg.Data.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid block data format")
	}

	// Convert to block (simplified)
	// In a real implementation, you'd properly deserialize the block
	// For now, we'll skip detailed validation

	e.logger.Infof("Received block from peer %s", from)
	return nil
}

// handleTransaction handles incoming transaction messages
func (e *Engine) handleTransaction(msg *network.Message, from peer.ID) error {
	_, ok := msg.Data.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid transaction data format")
	}

	// Convert to transaction (simplified)
	// In a real implementation, you'd properly deserialize the transaction
	// For now, we'll skip adding to blockchain

	e.logger.Infof("Received transaction from peer %s", from)
	return nil
}

// handleGetHeight handles height requests
func (e *Engine) handleGetHeight(msg *network.Message, from peer.ID) error {
	height := e.blockchain.GetHeight()

	return e.network.SendToPeer(from.String(), network.MsgTypeHeight, map[string]interface{}{
		"height": height,
	})
}

// handleGetBlocks handles block requests
func (e *Engine) handleGetBlocks(msg *network.Message, from peer.ID) error {
	data, ok := msg.Data.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid get blocks data format")
	}

	fromHeight, ok := data["from_height"].(float64)
	if !ok {
		return fmt.Errorf("invalid from_height")
	}

	// In a real implementation, you'd send the requested blocks
	e.logger.Infof("Received blocks request from peer %s, from height %d", from, int64(fromHeight))
	return nil
}

// SubmitTransaction submits a transaction to the network
func (e *Engine) SubmitTransaction(tx *types.Transaction) error {
	// Add to local blockchain
	if err := e.blockchain.AddTransaction(tx); err != nil {
		return fmt.Errorf("failed to add transaction locally: %v", err)
	}

	// Broadcast to network
	if err := e.network.Broadcast(network.MsgTypeTransaction, tx); err != nil {
		e.logger.Errorf("Failed to broadcast transaction: %v", err)
	}

	return nil
}

// GetBlockchain returns the blockchain instance
func (e *Engine) GetBlockchain() *blockchain.Blockchain {
	return e.blockchain
}

// IsValidator returns whether this node is a validator
func (e *Engine) IsValidator() bool {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.isValidator
}

// SetValidator sets validator status
func (e *Engine) SetValidator(isValidator bool) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.isValidator = isValidator
}
