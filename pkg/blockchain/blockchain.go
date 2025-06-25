package blockchain

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"agent-chain/pkg/types"
)

// Blockchain represents the main blockchain structure
type Blockchain struct {
	mu        sync.RWMutex
	blocks    []*types.Block
	accounts  map[types.Address]*types.Account
	txPool    map[types.Hash]*types.Transaction
	config    *types.ChainConfig
	dataDir   string
	lastBlock *types.Block
	height    int64
}

// NewBlockchain creates a new blockchain instance
func NewBlockchain(config *types.ChainConfig, dataDir string) (*Blockchain, error) {
	bc := &Blockchain{
		blocks:   make([]*types.Block, 0),
		accounts: make(map[types.Address]*types.Account),
		txPool:   make(map[types.Hash]*types.Transaction),
		config:   config,
		dataDir:  dataDir,
		height:   0,
	}

	// Create data directory
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create data directory: %v", err)
	}

	// Initialize genesis block
	if err := bc.initGenesis(); err != nil {
		return nil, fmt.Errorf("failed to initialize genesis: %v", err)
	}

	return bc, nil
}

// initGenesis creates the genesis block
func (bc *Blockchain) initGenesis() error {
	// Check if genesis already exists
	genesisPath := filepath.Join(bc.dataDir, "genesis.json")
	if _, err := os.Stat(genesisPath); err == nil {
		return bc.loadFromDisk()
	}

	// Create genesis block
	genesis := &types.Block{
		Header: types.BlockHeader{
			Height:     0,
			PrevHash:   types.Hash{},
			Timestamp:  time.Now().Unix(),
			Difficulty: 1,
			Nonce:      0,
		},
		Txs: []types.Transaction{},
	}

	genesis.Header.Hash = genesis.CalculateHash()
	bc.blocks = append(bc.blocks, genesis)
	bc.lastBlock = genesis

	// Initialize genesis accounts
	for _, acc := range bc.config.GenesisAccounts {
		bc.accounts[acc.Address] = &acc
	}

	return bc.saveToDisk()
}

// AddBlock adds a new block to the blockchain
func (bc *Blockchain) AddBlock(block *types.Block) error {
	bc.mu.Lock()
	defer bc.mu.Unlock()

	// Validate block
	if err := bc.validateBlock(block); err != nil {
		return fmt.Errorf("invalid block: %v", err)
	}

	// Apply transactions
	for _, tx := range block.Txs {
		if err := bc.applyTransaction(&tx); err != nil {
			return fmt.Errorf("failed to apply transaction: %v", err)
		}
		// Remove from tx pool
		delete(bc.txPool, tx.Hash)
	}

	// Add block
	bc.blocks = append(bc.blocks, block)
	bc.lastBlock = block
	bc.height = block.Header.Height

	return bc.saveToDisk()
}

// validateBlock validates a block
func (bc *Blockchain) validateBlock(block *types.Block) error {
	// Check height
	if block.Header.Height != bc.height+1 {
		return fmt.Errorf("invalid height: expected %d, got %d", bc.height+1, block.Header.Height)
	}

	// Check previous hash
	if bc.lastBlock != nil && block.Header.PrevHash != bc.lastBlock.Header.Hash {
		return fmt.Errorf("invalid previous hash")
	}

	// Validate hash
	expectedHash := block.CalculateHash()
	if block.Header.Hash != expectedHash {
		return fmt.Errorf("invalid block hash")
	}

	// Validate transactions
	for _, tx := range block.Txs {
		if err := bc.validateTransaction(&tx); err != nil {
			return fmt.Errorf("invalid transaction: %v", err)
		}
	}

	return nil
}

// AddTransaction adds a transaction to the pool
func (bc *Blockchain) AddTransaction(tx *types.Transaction) error {
	bc.mu.Lock()
	defer bc.mu.Unlock()

	// Validate transaction
	if err := bc.validateTransaction(tx); err != nil {
		return err
	}

	// Calculate hash
	tx.Hash = tx.CalculateHash()

	// Add to pool
	bc.txPool[tx.Hash] = tx

	return nil
}

// validateTransaction validates a transaction
func (bc *Blockchain) validateTransaction(tx *types.Transaction) error {
	// Check if transaction already exists
	if _, exists := bc.txPool[tx.Hash]; exists {
		return fmt.Errorf("transaction already in pool")
	}

	// Validate signature (simplified)
	if len(tx.Signature) == 0 {
		return fmt.Errorf("missing signature")
	}

	// Check account balance for transfer transactions
	if tx.Type == types.TxTypeTransfer {
		account := bc.GetAccount(tx.From)
		if account.Balance < tx.Amount {
			return fmt.Errorf("insufficient balance")
		}
	}

	return nil
}

// applyTransaction applies a transaction to the state
func (bc *Blockchain) applyTransaction(tx *types.Transaction) error {
	switch tx.Type {
	case types.TxTypeTransfer:
		return bc.applyTransfer(tx)
	case types.TxTypePatchSubmit:
		return bc.applyPatchSubmit(tx)
	default:
		return fmt.Errorf("unknown transaction type: %s", tx.Type)
	}
}

// applyTransfer applies a transfer transaction
func (bc *Blockchain) applyTransfer(tx *types.Transaction) error {
	fromAccount := bc.GetAccount(tx.From)
	toAccount := bc.GetAccount(tx.To)

	if fromAccount.Balance < tx.Amount {
		return fmt.Errorf("insufficient balance")
	}

	fromAccount.Balance -= tx.Amount
	fromAccount.Nonce++
	toAccount.Balance += tx.Amount

	bc.accounts[tx.From] = fromAccount
	bc.accounts[tx.To] = toAccount

	return nil
}

// applyPatchSubmit applies a patch submission transaction
func (bc *Blockchain) applyPatchSubmit(tx *types.Transaction) error {
	if tx.PatchSet == nil {
		return fmt.Errorf("missing patch set")
	}

	// Award tokens for successful patch submission
	account := bc.GetAccount(tx.From)
	account.Balance += bc.config.InitialReward
	account.Nonce++
	bc.accounts[tx.From] = account

	return nil
}

// GetAccount returns account information
func (bc *Blockchain) GetAccount(addr types.Address) *types.Account {
	if account, exists := bc.accounts[addr]; exists {
		return account
	}

	// Return empty account if not found
	return &types.Account{
		Address: addr,
		Balance: 0,
		Nonce:   0,
	}
}

// GetHeight returns current blockchain height
func (bc *Blockchain) GetHeight() int64 {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	return bc.height
}

// GetLastBlock returns the last block
func (bc *Blockchain) GetLastBlock() *types.Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	return bc.lastBlock
}

// GetPendingTransactions returns pending transactions
func (bc *Blockchain) GetPendingTransactions() []*types.Transaction {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	txs := make([]*types.Transaction, 0, len(bc.txPool))
	for _, tx := range bc.txPool {
		txs = append(txs, tx)
	}
	return txs
}

// saveToDisk saves blockchain state to disk
func (bc *Blockchain) saveToDisk() error {
	// Save blocks
	blocksPath := filepath.Join(bc.dataDir, "blocks.json")
	blocksData, err := json.MarshalIndent(bc.blocks, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(blocksPath, blocksData, 0644); err != nil {
		return err
	}

	// Save accounts - convert map to slice for JSON serialization
	accountsPath := filepath.Join(bc.dataDir, "accounts.json")
	accountsList := make([]*types.Account, 0, len(bc.accounts))
	for _, account := range bc.accounts {
		accountsList = append(accountsList, account)
	}
	accountsData, err := json.MarshalIndent(accountsList, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(accountsPath, accountsData, 0644)
}

// loadFromDisk loads blockchain state from disk
func (bc *Blockchain) loadFromDisk() error {
	// Load blocks
	blocksPath := filepath.Join(bc.dataDir, "blocks.json")
	blocksData, err := os.ReadFile(blocksPath)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(blocksData, &bc.blocks); err != nil {
		return err
	}

	// Load accounts - convert slice back to map
	accountsPath := filepath.Join(bc.dataDir, "accounts.json")
	accountsData, err := os.ReadFile(accountsPath)
	if err != nil {
		return err
	}
	var accountsList []*types.Account
	if err := json.Unmarshal(accountsData, &accountsList); err != nil {
		return err
	}

	// Convert slice back to map
	bc.accounts = make(map[types.Address]*types.Account)
	for _, account := range accountsList {
		bc.accounts[account.Address] = account
	}

	// Set last block and height
	if len(bc.blocks) > 0 {
		bc.lastBlock = bc.blocks[len(bc.blocks)-1]
		bc.height = bc.lastBlock.Header.Height
	}

	return nil
}
