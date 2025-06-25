package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	"agent-chain/pkg/blockchain"
	"agent-chain/pkg/consensus"
	"agent-chain/pkg/crypto"
	"agent-chain/pkg/network"
	"agent-chain/pkg/types"
)

type Node struct {
	blockchain *blockchain.Blockchain
	network    *network.Network
	consensus  *consensus.Engine
	keyPair    *crypto.KeyPair
	config     *NodeConfig
	logger     *logrus.Logger
	httpServer *http.Server
}

type NodeConfig struct {
	DataDir       string   `mapstructure:"data_dir"`
	P2PPort       int      `mapstructure:"p2p_port"`
	RPCPort       int      `mapstructure:"rpc_port"`
	PrivateKey    string   `mapstructure:"private_key"`
	BootNodes     []string `mapstructure:"boot_nodes"`
	IsValidator   bool     `mapstructure:"is_validator"`
	IsBootstrap   bool     `mapstructure:"is_bootstrap"`
	EnableDiscovery bool   `mapstructure:"enable_discovery"`
}

func main() {
	var configFile string
	var isBootstrap bool
	var enableDiscovery bool

	var rootCmd = &cobra.Command{
		Use:   "node",
		Short: "Agent Chain Node",
		Long:  "Blockchain node for Agent Chain network",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runNode(configFile, isBootstrap, enableDiscovery)
		},
	}

	rootCmd.Flags().StringVar(&configFile, "config", "", "Config file path")
	rootCmd.Flags().BoolVar(&isBootstrap, "bootstrap", false, "Run as bootstrap node to help other nodes discover the network")
	rootCmd.Flags().BoolVar(&enableDiscovery, "discovery", true, "Enable automatic peer discovery")

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runNode(configFile string, isBootstrap bool, enableDiscovery bool) error {
	// Setup logger
	logger := logrus.New()
	logger.SetLevel(logrus.InfoLevel)

	// Load configuration
	config, err := loadConfig(configFile)
	if err != nil {
		return fmt.Errorf("failed to load config: %v", err)
	}

	// Override config with command line flags
	config.IsBootstrap = isBootstrap
	config.EnableDiscovery = enableDiscovery

	// Create data directory
	if err := os.MkdirAll(config.DataDir, 0755); err != nil {
		return fmt.Errorf("failed to create data directory: %v", err)
	}

	// Load or generate key pair
	keyPair, err := loadOrGenerateKeyPair(config)
	if err != nil {
		return fmt.Errorf("failed to load key pair: %v", err)
	}

	// Create blockchain config
	chainConfig := &types.ChainConfig{
		ChainID:         1,
		BlockTime:       types.DefaultBlockTime,
		MaxBlockSize:    types.DefaultMaxBlockSize,
		MaxTxPerBlock:   types.DefaultMaxTxPerBlock,
		InitialReward:   types.DefaultInitialReward,
		RewardDecay:     0.99,
		GenesisAccounts: createGenesisAccounts(),
	}

	// Initialize blockchain
	bc, err := blockchain.NewBlockchain(chainConfig, filepath.Join(config.DataDir, "blockchain"))
	if err != nil {
		return fmt.Errorf("failed to create blockchain: %v", err)
	}

	// Initialize network
	net, err := network.NewNetwork(config.P2PPort, logger)
	if err != nil {
		return fmt.Errorf("failed to create network: %v", err)
	}

	// Initialize consensus
	cons := consensus.NewEngine(bc, net, keyPair, chainConfig, logger)

	// Create node
	node := &Node{
		blockchain: bc,
		network:    net,
		consensus:  cons,
		keyPair:    keyPair,
		config:     config,
		logger:     logger,
	}

	// Start services
	if err := node.start(); err != nil {
		return fmt.Errorf("failed to start node: %v", err)
	}

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	logger.Info("Shutting down node...")
	return node.stop()
}

func (n *Node) start() error {
	// Enable bootstrap mode if configured
	if n.config.IsBootstrap {
		n.network.EnableBootstrapMode()
		n.logger.Info("Bootstrap mode enabled - this node will help others discover the network")
	}

	// Start network with P2P discovery
	if err := n.network.Start(); err != nil {
		return fmt.Errorf("failed to start network: %v", err)
	}

	// Connect to boot nodes (legacy support)
	for _, bootNode := range n.config.BootNodes {
		if err := n.network.ConnectToPeer(bootNode); err != nil {
			n.logger.Warnf("Failed to connect to boot node %s: %v", bootNode, err)
		}
	}

	// Start consensus
	if err := n.consensus.Start(); err != nil {
		return fmt.Errorf("failed to start consensus: %v", err)
	}

	// Start RPC server
	if err := n.startRPCServer(); err != nil {
		return fmt.Errorf("failed to start RPC server: %v", err)
	}

	// Log discovery stats
	if n.config.EnableDiscovery {
		stats := n.network.GetDiscoveryStats()
		n.logger.Infof("P2P Discovery enabled: %+v", stats)
	}

	n.logger.Infof("Node started successfully")
	n.logger.Infof("Node ID: %s", n.network.GetID())
	n.logger.Infof("Address: %s", n.keyPair.GetAddress().String())
	n.logger.Infof("P2P Port: %d", n.config.P2PPort)
	n.logger.Infof("RPC Port: %d", n.config.RPCPort)

	return nil
}

func (n *Node) stop() error {
	// Stop RPC server
	if n.httpServer != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		n.httpServer.Shutdown(ctx)
	}

	// Stop consensus
	n.consensus.Stop()

	// Stop network
	n.network.Stop()

	n.logger.Info("Node stopped")
	return nil
}

func (n *Node) startRPCServer() error {
	router := mux.NewRouter()

	// RPC endpoints
	router.HandleFunc("/", n.handleRPC).Methods("POST")
	router.HandleFunc("/health", n.handleHealth).Methods("GET")

	n.httpServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", n.config.RPCPort),
		Handler: router,
	}

	go func() {
		if err := n.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			n.logger.Errorf("RPC server error: %v", err)
		}
	}()

	return nil
}

func (n *Node) handleRPC(w http.ResponseWriter, r *http.Request) {
	var req map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	method, ok := req["method"].(string)
	if !ok {
		http.Error(w, "Missing method", http.StatusBadRequest)
		return
	}

	var response interface{}
	var err error

	switch method {
	case "get_height":
		response = map[string]interface{}{
			"height": n.blockchain.GetHeight(),
		}
	case "get_balance":
		response, err = n.handleGetBalance(req["params"])
	case "submit_transaction":
		response, err = n.handleSubmitTransaction(req["params"])
	default:
		http.Error(w, "Unknown method", http.StatusBadRequest)
		return
	}

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (n *Node) handleGetBalance(params interface{}) (interface{}, error) {
	paramsMap, ok := params.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid params")
	}

	addressStr, ok := paramsMap["address"].(string)
	if !ok {
		return nil, fmt.Errorf("missing address")
	}

	address, err := crypto.AddressFromString(addressStr)
	if err != nil {
		return nil, fmt.Errorf("invalid address: %v", err)
	}

	account := n.blockchain.GetAccount(address)

	return map[string]interface{}{
		"balance": account.Balance,
		"nonce":   account.Nonce,
	}, nil
}

func (n *Node) handleSubmitTransaction(params interface{}) (interface{}, error) {
	// In a real implementation, you'd properly deserialize the transaction
	// For now, return a mock response
	return map[string]interface{}{
		"tx_hash": "0x1234567890abcdef",
	}, nil
}

func (n *Node) handleHealth(w http.ResponseWriter, r *http.Request) {
	response := map[string]interface{}{
		"status":    "ok",
		"height":    n.blockchain.GetHeight(),
		"peers":     n.network.GetPeerCount(),
		"node_id":   n.network.GetID(),
		"timestamp": time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func loadConfig(configFile string) (*NodeConfig, error) {
	config := &NodeConfig{
		DataDir:     "./data",
		P2PPort:     9000,
		RPCPort:     8545,
		IsValidator: true,
		BootNodes:   []string{},
	}

	if configFile != "" {
		viper.SetConfigFile(configFile)
		if err := viper.ReadInConfig(); err != nil {
			return nil, err
		}
		if err := viper.Unmarshal(config); err != nil {
			return nil, err
		}
	}

	return config, nil
}

func loadOrGenerateKeyPair(config *NodeConfig) (*crypto.KeyPair, error) {
	if config.PrivateKey != "" {
		return crypto.PrivateKeyFromHex(config.PrivateKey)
	}

	// Generate new key pair
	keyPair, err := crypto.GenerateKeyPair()
	if err != nil {
		return nil, err
	}

	// Save private key to config file for persistence
	keyFile := filepath.Join(config.DataDir, "node.key")
	if err := os.WriteFile(keyFile, []byte(keyPair.PrivateKeyToHex()), 0600); err != nil {
		return nil, err
	}

	return keyPair, nil
}

func createGenesisAccounts() []types.Account {
	// Create some genesis accounts with initial balances
	accounts := []types.Account{}

	// Generate a few test accounts
	for i := 0; i < 3; i++ {
		keyPair, _ := crypto.GenerateKeyPair()
		account := types.Account{
			Address: keyPair.GetAddress(),
			Balance: 1000000, // 1M tokens
			Nonce:   0,
		}
		accounts = append(accounts, account)
	}

	return accounts
}
