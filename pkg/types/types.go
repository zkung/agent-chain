package types

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"time"
)

// Hash represents a 32-byte hash
type Hash [32]byte

func (h Hash) String() string {
	return hex.EncodeToString(h[:])
}

func (h Hash) Bytes() []byte {
	return h[:]
}

func NewHash(data []byte) Hash {
	return sha256.Sum256(data)
}

// Address represents a 20-byte address
type Address [20]byte

func (a Address) String() string {
	return "0x" + hex.EncodeToString(a[:])
}

func (a Address) Bytes() []byte {
	return a[:]
}

// ProblemSpec defines a task specification
type ProblemSpec struct {
	ID                 string            `json:"id"`
	Title              string            `json:"title"`
	Description        string            `json:"description"`
	InputFormat        map[string]string `json:"input_format"`
	OutputFormat       map[string]string `json:"output_format"`
	AcceptanceCriteria []string          `json:"acceptance_criteria"`
	TimeLimitMs        int64             `json:"time_limit_ms"`
	MemoryLimitMb      int64             `json:"memory_limit_mb"`
	Reward             int64             `json:"reward"`
	TestSuite          []TestCase        `json:"test_suite"`
}

// TestCase represents a single test case
type TestCase struct {
	Input    string `json:"input"`
	Expected string `json:"expected"`
	Weight   int    `json:"weight"`
}

// PatchSet represents a code submission
type PatchSet struct {
	ID        string            `json:"id"`
	ProblemID string            `json:"problem_id"`
	Author    Address           `json:"author"`
	Code      string            `json:"code"`
	Language  string            `json:"language"`
	Files     map[string]string `json:"files"`
	Timestamp int64             `json:"timestamp"`
	Signature []byte            `json:"signature"`
}

func (ps *PatchSet) Hash() Hash {
	data, _ := json.Marshal(ps)
	return NewHash(data)
}

// Transaction represents a blockchain transaction
type Transaction struct {
	Type      string    `json:"type"`
	From      Address   `json:"from"`
	To        Address   `json:"to"`
	Amount    int64     `json:"amount"`
	PatchSet  *PatchSet `json:"patch_set,omitempty"`
	Timestamp int64     `json:"timestamp"`
	Nonce     int64     `json:"nonce"`
	Signature []byte    `json:"signature"`
	Hash      Hash      `json:"hash"`
}

func (tx *Transaction) CalculateHash() Hash {
	// Create a copy without hash and signature for calculation
	temp := *tx
	temp.Hash = Hash{}
	temp.Signature = nil
	data, _ := json.Marshal(temp)
	return NewHash(data)
}

// Block represents a blockchain block
type Block struct {
	Header BlockHeader   `json:"header"`
	Txs    []Transaction `json:"transactions"`
}

// BlockHeader contains block metadata
type BlockHeader struct {
	Height     int64   `json:"height"`
	PrevHash   Hash    `json:"prev_hash"`
	MerkleRoot Hash    `json:"merkle_root"`
	Timestamp  int64   `json:"timestamp"`
	Difficulty int64   `json:"difficulty"`
	Nonce      int64   `json:"nonce"`
	Validator  Address `json:"validator"`
	Hash       Hash    `json:"hash"`
}

func (b *Block) CalculateHash() Hash {
	// Calculate merkle root of transactions
	b.Header.MerkleRoot = b.calculateMerkleRoot()

	// Create header copy without hash for calculation
	temp := b.Header
	temp.Hash = Hash{}
	data, _ := json.Marshal(temp)
	return NewHash(data)
}

func (b *Block) calculateMerkleRoot() Hash {
	if len(b.Txs) == 0 {
		return Hash{}
	}

	var hashes []Hash
	for _, tx := range b.Txs {
		hashes = append(hashes, tx.Hash)
	}

	// Simple merkle tree implementation
	for len(hashes) > 1 {
		var nextLevel []Hash
		for i := 0; i < len(hashes); i += 2 {
			if i+1 < len(hashes) {
				combined := append(hashes[i][:], hashes[i+1][:]...)
				nextLevel = append(nextLevel, NewHash(combined))
			} else {
				nextLevel = append(nextLevel, hashes[i])
			}
		}
		hashes = nextLevel
	}

	return hashes[0]
}

// Account represents a user account
type Account struct {
	Address  Address `json:"address"`
	Balance  int64   `json:"balance"`
	Nonce    int64   `json:"nonce"`
	CodeHash Hash    `json:"code_hash,omitempty"`
}

// NodeInfo represents node information
type NodeInfo struct {
	ID        string    `json:"id"`
	Address   string    `json:"address"`
	Port      int       `json:"port"`
	PublicKey []byte    `json:"public_key"`
	LastSeen  time.Time `json:"last_seen"`
}

// ChainConfig represents blockchain configuration
type ChainConfig struct {
	ChainID         int64         `json:"chain_id"`
	BlockTime       time.Duration `json:"block_time"`
	MaxBlockSize    int64         `json:"max_block_size"`
	MaxTxPerBlock   int           `json:"max_tx_per_block"`
	InitialReward   int64         `json:"initial_reward"`
	RewardDecay     float64       `json:"reward_decay"`
	GenesisAccounts []Account     `json:"genesis_accounts"`
}

// Constants
const (
	TxTypeTransfer    = "transfer"
	TxTypePatchSubmit = "patch_submit"
	TxTypeStake       = "stake"

	DefaultBlockTime     = 10 * time.Second
	DefaultMaxBlockSize  = 1024 * 1024 // 1MB
	DefaultMaxTxPerBlock = 1000
	DefaultInitialReward = 1000
)
