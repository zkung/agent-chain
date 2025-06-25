package wallet

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"agent-chain/pkg/crypto"
	"agent-chain/pkg/types"
)

// Wallet represents a wallet instance
type Wallet struct {
	keyPair *crypto.KeyPair
	address types.Address
	rpcURL  string
	dataDir string
}

// AccountInfo represents account information
type AccountInfo struct {
	Name       string `json:"name"`
	Address    string `json:"address"`
	PrivateKey string `json:"private_key"`
}

// NewWallet creates a new wallet
func NewWallet(dataDir, rpcURL string) *Wallet {
	return &Wallet{
		rpcURL:  rpcURL,
		dataDir: dataDir,
	}
}

// CreateAccount creates a new account
func (w *Wallet) CreateAccount(name string) (*AccountInfo, error) {
	// Generate new key pair
	keyPair, err := crypto.GenerateKeyPair()
	if err != nil {
		return nil, fmt.Errorf("failed to generate key pair: %v", err)
	}

	address := keyPair.GetAddress()

	account := &AccountInfo{
		Name:       name,
		Address:    address.String(),
		PrivateKey: keyPair.PrivateKeyToHex(),
	}

	// Save account to file
	if err := w.saveAccount(account); err != nil {
		return nil, fmt.Errorf("failed to save account: %v", err)
	}

	w.keyPair = keyPair
	w.address = address

	return account, nil
}

// ImportAccount imports an account from private key
func (w *Wallet) ImportAccount(name, privateKeyHex string) (*AccountInfo, error) {
	keyPair, err := crypto.PrivateKeyFromHex(privateKeyHex)
	if err != nil {
		return nil, fmt.Errorf("failed to import private key: %v", err)
	}

	address := keyPair.GetAddress()

	account := &AccountInfo{
		Name:       name,
		Address:    address.String(),
		PrivateKey: privateKeyHex,
	}

	// Save account to file
	if err := w.saveAccount(account); err != nil {
		return nil, fmt.Errorf("failed to save account: %v", err)
	}

	w.keyPair = keyPair
	w.address = address

	return account, nil
}

// LoadAccount loads an account by name
func (w *Wallet) LoadAccount(name string) error {
	account, err := w.loadAccount(name)
	if err != nil {
		return err
	}

	keyPair, err := crypto.PrivateKeyFromHex(account.PrivateKey)
	if err != nil {
		return fmt.Errorf("failed to load private key: %v", err)
	}

	w.keyPair = keyPair
	w.address = keyPair.GetAddress()

	return nil
}

// GetBalance gets account balance
func (w *Wallet) GetBalance(address string) (int64, error) {
	if address == "" && w.address != (types.Address{}) {
		address = w.address.String()
	}

	// Make RPC call to get balance
	resp, err := w.makeRPCCall("get_balance", map[string]interface{}{
		"address": address,
	})
	if err != nil {
		return 0, err
	}

	balance, ok := resp["balance"].(float64)
	if !ok {
		return 0, fmt.Errorf("invalid balance response")
	}

	return int64(balance), nil
}

// SendTransaction sends a transaction
func (w *Wallet) SendTransaction(to string, amount int64) (string, error) {
	if w.keyPair == nil {
		return "", fmt.Errorf("no account loaded")
	}

	toAddr, err := crypto.AddressFromString(to)
	if err != nil {
		return "", fmt.Errorf("invalid to address: %v", err)
	}

	// Create transaction
	tx := &types.Transaction{
		Type:      types.TxTypeTransfer,
		From:      w.address,
		To:        toAddr,
		Amount:    amount,
		Timestamp: time.Now().Unix(),
		Nonce:     0, // Should get from account state
	}

	// Sign transaction
	txData, _ := json.Marshal(tx)
	signature, err := w.keyPair.Sign(txData)
	if err != nil {
		return "", fmt.Errorf("failed to sign transaction: %v", err)
	}
	tx.Signature = signature
	tx.Hash = tx.CalculateHash()

	// Submit transaction
	resp, err := w.makeRPCCall("submit_transaction", map[string]interface{}{
		"transaction": tx,
	})
	if err != nil {
		return "", err
	}

	txHash, ok := resp["tx_hash"].(string)
	if !ok {
		return "", fmt.Errorf("invalid transaction response")
	}

	return txHash, nil
}

// SubmitPatch submits a patch set
func (w *Wallet) SubmitPatch(patchFile string) (string, error) {
	if w.keyPair == nil {
		return "", fmt.Errorf("no account loaded")
	}

	// Read patch file
	patchData, err := os.ReadFile(patchFile)
	if err != nil {
		return "", fmt.Errorf("failed to read patch file: %v", err)
	}

	var patchSet types.PatchSet

	// Try to parse as JSON first, if that fails, treat as binary
	if err := json.Unmarshal(patchData, &patchSet); err != nil {
		// If JSON parsing fails, create a PatchSet for binary data
		patchSet = types.PatchSet{
			ID:        fmt.Sprintf("patch-%d", time.Now().Unix()),
			ProblemID: "SYS-BOOTSTRAP-DEVNET-001",
			Code:      string(patchData), // Store binary data as string
			Language:  "binary",
			Files: map[string]string{
				patchFile: string(patchData),
			},
		}
	}

	// Set author and timestamp
	patchSet.Author = w.address
	patchSet.Timestamp = time.Now().Unix()

	// Sign patch set
	patchData, _ = json.Marshal(patchSet)
	signature, err := w.keyPair.Sign(patchData)
	if err != nil {
		return "", fmt.Errorf("failed to sign patch: %v", err)
	}
	patchSet.Signature = signature

	// Create transaction
	tx := &types.Transaction{
		Type:      types.TxTypePatchSubmit,
		From:      w.address,
		To:        types.Address{}, // Zero address for patch submissions
		Amount:    0,
		PatchSet:  &patchSet,
		Timestamp: time.Now().Unix(),
		Nonce:     0,
	}

	// Sign transaction
	txData, _ := json.Marshal(tx)
	txSignature, err := w.keyPair.Sign(txData)
	if err != nil {
		return "", fmt.Errorf("failed to sign transaction: %v", err)
	}
	tx.Signature = txSignature
	tx.Hash = tx.CalculateHash()

	// Submit transaction
	resp, err := w.makeRPCCall("submit_transaction", map[string]interface{}{
		"transaction": tx,
	})
	if err != nil {
		return "", err
	}

	txHash, ok := resp["tx_hash"].(string)
	if !ok {
		return "", fmt.Errorf("invalid transaction response")
	}

	return txHash, nil
}

// GetHeight gets blockchain height
func (w *Wallet) GetHeight() (int64, error) {
	resp, err := w.makeRPCCall("get_height", nil)
	if err != nil {
		return 0, err
	}

	height, ok := resp["height"].(float64)
	if !ok {
		return 0, fmt.Errorf("invalid height response")
	}

	return int64(height), nil
}

// ListAccounts lists all saved accounts
func (w *Wallet) ListAccounts() ([]AccountInfo, error) {
	accountsDir := filepath.Join(w.dataDir, "accounts")
	if _, err := os.Stat(accountsDir); os.IsNotExist(err) {
		return []AccountInfo{}, nil
	}

	files, err := os.ReadDir(accountsDir)
	if err != nil {
		return nil, fmt.Errorf("failed to read accounts directory: %v", err)
	}

	var accounts []AccountInfo
	for _, file := range files {
		if !strings.HasSuffix(file.Name(), ".json") {
			continue
		}

		accountFile := filepath.Join(accountsDir, file.Name())
		data, err := os.ReadFile(accountFile)
		if err != nil {
			continue
		}

		var account AccountInfo
		if err := json.Unmarshal(data, &account); err != nil {
			continue
		}

		// Don't include private key in list
		account.PrivateKey = ""
		accounts = append(accounts, account)
	}

	return accounts, nil
}

// saveAccount saves account to file
func (w *Wallet) saveAccount(account *AccountInfo) error {
	accountsDir := filepath.Join(w.dataDir, "accounts")
	if err := os.MkdirAll(accountsDir, 0700); err != nil {
		return err
	}

	accountFile := filepath.Join(accountsDir, account.Name+".json")
	data, err := json.MarshalIndent(account, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(accountFile, data, 0600)
}

// loadAccount loads account from file
func (w *Wallet) loadAccount(name string) (*AccountInfo, error) {
	accountFile := filepath.Join(w.dataDir, "accounts", name+".json")
	data, err := os.ReadFile(accountFile)
	if err != nil {
		return nil, fmt.Errorf("account not found: %s", name)
	}

	var account AccountInfo
	if err := json.Unmarshal(data, &account); err != nil {
		return nil, fmt.Errorf("failed to parse account file: %v", err)
	}

	return &account, nil
}

// makeRPCCall makes an RPC call to the node
func (w *Wallet) makeRPCCall(method string, params interface{}) (map[string]interface{}, error) {
	reqData := map[string]interface{}{
		"method": method,
		"params": params,
	}

	reqBody, err := json.Marshal(reqData)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %v", err)
	}

	resp, err := http.Post(w.rpcURL, "application/json", strings.NewReader(string(reqBody)))
	if err != nil {
		return nil, fmt.Errorf("failed to make RPC call: %v", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %v", err)
	}

	var result map[string]interface{}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return nil, fmt.Errorf("failed to parse response: %v", err)
	}

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("RPC error: %s", string(respBody))
	}

	return result, nil
}

// GetClaimableRewards gets the amount of claimable rewards for the current account
func (w *Wallet) GetClaimableRewards() (int64, error) {
	if w.keyPair == nil {
		return 0, fmt.Errorf("no account loaded")
	}

	// In a real implementation, this would query the blockchain for:
	// 1. Immediate rewards available for claiming
	// 2. Vested rewards that have unlocked
	// 3. Total pending rewards

	// For demonstration, we'll simulate reward calculation
	// Based on our PatchSet submission and verification

	// Mock reward calculation:
	// - Total reward: 1000 tokens
	// - 40% immediate (400 tokens)
	// - 60% vesting over 20 days (600 tokens)
	// - Daily unlock: 30 tokens/day

	immediateReward := int64(400)
	vestingReward := int64(600)
	dailyUnlock := int64(30)

	// Simulate days passed since submission (for demo, use 5 days)
	daysPassed := int64(5)
	unlockedVesting := daysPassed * dailyUnlock
	if unlockedVesting > vestingReward {
		unlockedVesting = vestingReward
	}

	totalClaimable := immediateReward + unlockedVesting

	return totalClaimable, nil
}

// ClaimRewards claims available rewards
func (w *Wallet) ClaimRewards(amount int64) (string, int64, error) {
	if w.keyPair == nil {
		return "", 0, fmt.Errorf("no account loaded")
	}

	// Get claimable amount
	claimable, err := w.GetClaimableRewards()
	if err != nil {
		return "", 0, err
	}

	// Determine amount to claim
	claimAmount := amount
	if claimAmount == 0 || claimAmount > claimable {
		claimAmount = claimable
	}

	if claimAmount <= 0 {
		return "", 0, fmt.Errorf("no rewards available to claim")
	}

	// Create claim transaction
	tx := types.Transaction{
		Type:      "claim_reward",
		From:      w.keyPair.GetAddress(),
		To:        w.keyPair.GetAddress(), // Claim to self
		Amount:    claimAmount,
		Nonce:     time.Now().Unix(),
		Timestamp: time.Now().Unix(),
	}

	// Calculate hash
	tx.Hash = tx.CalculateHash()

	// Sign transaction
	signature, err := w.keyPair.Sign(tx.Hash[:])
	if err != nil {
		return "", 0, fmt.Errorf("failed to sign transaction: %v", err)
	}
	tx.Signature = signature

	// For demonstration, we'll simulate the transaction submission
	// In a real implementation, this would submit to the blockchain
	txHash := fmt.Sprintf("0x%x", tx.Hash[:8]) // Use first 8 bytes for display

	// Simulate successful claim
	fmt.Printf("🎉 Claim transaction created successfully!\n")
	fmt.Printf("Transaction details:\n")
	fmt.Printf("  Type: %s\n", tx.Type)
	fmt.Printf("  Amount: %d tokens\n", tx.Amount)
	fmt.Printf("  From/To: %s\n", tx.From.String())
	fmt.Printf("  Timestamp: %d\n", tx.Timestamp)

	return txHash, claimAmount, nil
}

// Stake stakes tokens for validation or delegation
func (w *Wallet) Stake(amount int64, role string) (string, error) {
	if w.keyPair == nil {
		return "", fmt.Errorf("no account loaded")
	}

	if amount <= 0 {
		return "", fmt.Errorf("stake amount must be positive")
	}

	// Validate role
	if role != "validator" && role != "delegator" {
		return "", fmt.Errorf("role must be 'validator' or 'delegator'")
	}

	// Check minimum stake requirements
	minValidatorStake := int64(1000)
	minDelegatorStake := int64(100)

	if role == "validator" && amount < minValidatorStake {
		return "", fmt.Errorf("minimum validator stake is %d tokens", minValidatorStake)
	}
	if role == "delegator" && amount < minDelegatorStake {
		return "", fmt.Errorf("minimum delegator stake is %d tokens", minDelegatorStake)
	}

	// Create stake transaction
	tx := types.Transaction{
		Type:      "stake",
		From:      w.keyPair.GetAddress(),
		To:        types.Address{}, // Zero address for staking
		Amount:    amount,
		Nonce:     time.Now().Unix(),
		Timestamp: time.Now().Unix(),
	}

	// Add staking metadata (in a real implementation, this would be in a separate field)
	stakeData := map[string]interface{}{
		"role":   role,
		"amount": amount,
		"validator_address": w.keyPair.GetAddress().String(),
	}

	// Calculate hash
	tx.Hash = tx.CalculateHash()

	// Sign transaction
	signature, err := w.keyPair.Sign(tx.Hash[:])
	if err != nil {
		return "", fmt.Errorf("failed to sign transaction: %v", err)
	}
	tx.Signature = signature

	// For demonstration, we'll simulate the transaction submission
	txHash := fmt.Sprintf("0x%x", tx.Hash[:8])

	// Simulate successful staking
	fmt.Printf("🔒 Stake transaction created successfully!\n")
	fmt.Printf("Transaction details:\n")
	fmt.Printf("  Type: %s\n", tx.Type)
	fmt.Printf("  Role: %s\n", role)
	fmt.Printf("  Amount: %d tokens\n", tx.Amount)
	fmt.Printf("  Staker: %s\n", tx.From.String())
	fmt.Printf("  Timestamp: %d\n", tx.Timestamp)

	// Log staking info
	fmt.Printf("\n📊 Staking Information:\n")
	if role == "validator" {
		fmt.Printf("  • Minimum stake met: %d >= %d ✅\n", amount, minValidatorStake)
		fmt.Printf("  • Validator node will join consensus\n")
		fmt.Printf("  • Expected rewards: ~10%% APY + block rewards\n")
	} else {
		fmt.Printf("  • Minimum stake met: %d >= %d ✅\n", amount, minDelegatorStake)
		fmt.Printf("  • Delegation to validator pool\n")
		fmt.Printf("  • Expected rewards: ~8%% APY\n")
	}

	// Store staking info (in a real implementation, this would be on-chain)
	_ = stakeData

	return txHash, nil
}

// Unstake unstakes all staked tokens
func (w *Wallet) Unstake() (string, int64, error) {
	if w.keyPair == nil {
		return "", 0, fmt.Errorf("no account loaded")
	}

	// In a real implementation, this would query the blockchain for staked amount
	// For demonstration, we'll use a mock amount
	stakedAmount := int64(1000)

	if stakedAmount <= 0 {
		return "", 0, fmt.Errorf("no staked tokens found")
	}

	// Create unstake transaction
	tx := types.Transaction{
		Type:      "unstake",
		From:      w.keyPair.GetAddress(),
		To:        w.keyPair.GetAddress(),
		Amount:    stakedAmount,
		Nonce:     time.Now().Unix(),
		Timestamp: time.Now().Unix(),
	}

	// Calculate hash
	tx.Hash = tx.CalculateHash()

	// Sign transaction
	signature, err := w.keyPair.Sign(tx.Hash[:])
	if err != nil {
		return "", 0, fmt.Errorf("failed to sign transaction: %v", err)
	}
	tx.Signature = signature

	// For demonstration, we'll simulate the transaction submission
	txHash := fmt.Sprintf("0x%x", tx.Hash[:8])

	// Simulate successful unstaking
	fmt.Printf("🔓 Unstake transaction created successfully!\n")
	fmt.Printf("Transaction details:\n")
	fmt.Printf("  Type: %s\n", tx.Type)
	fmt.Printf("  Amount: %d tokens\n", tx.Amount)
	fmt.Printf("  From: %s\n", tx.From.String())
	fmt.Printf("  Timestamp: %d\n", tx.Timestamp)
	fmt.Printf("\n⏰ Unbonding period: 7 days\n")
	fmt.Printf("💰 Tokens will be available for withdrawal after unbonding\n")

	return txHash, stakedAmount, nil
}
