package main

import (
	"fmt"
	"os"
	"path/filepath"

	"agent-chain/pkg/wallet"
	"github.com/spf13/cobra"
)

var (
	dataDir string
	rpcURL  string
	w       *wallet.Wallet
)

func main() {
	var rootCmd = &cobra.Command{
		Use:   "wallet",
		Short: "Agent Chain CLI Wallet",
		Long:  "Command line wallet for Agent Chain blockchain",
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			w = wallet.NewWallet(dataDir, rpcURL)
		},
	}

	// Global flags
	rootCmd.PersistentFlags().StringVar(&dataDir, "data-dir", getDefaultDataDir(), "Data directory")
	rootCmd.PersistentFlags().StringVar(&rpcURL, "rpc", "http://127.0.0.1:8545", "RPC endpoint")

	// Add commands
	rootCmd.AddCommand(newCmd())
	rootCmd.AddCommand(importCmd())
	rootCmd.AddCommand(listCmd())
	rootCmd.AddCommand(balanceCmd())
	rootCmd.AddCommand(sendCmd())
	rootCmd.AddCommand(receiveCmd())
	rootCmd.AddCommand(submitPatchCmd())
	rootCmd.AddCommand(claimCmd())
	rootCmd.AddCommand(stakeCmd())
	rootCmd.AddCommand(heightCmd())

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func newCmd() *cobra.Command {
	var name string

	cmd := &cobra.Command{
		Use:   "new",
		Short: "Create a new account",
		RunE: func(cmd *cobra.Command, args []string) error {
			account, err := w.CreateAccount(name)
			if err != nil {
				return err
			}

			fmt.Printf("Created new account:\n")
			fmt.Printf("Name: %s\n", account.Name)
			fmt.Printf("Address: %s\n", account.Address)
			fmt.Printf("Private Key: %s\n", account.PrivateKey)

			return nil
		},
	}

	cmd.Flags().StringVar(&name, "name", "", "Account name (required)")
	cmd.MarkFlagRequired("name")

	return cmd
}

func importCmd() *cobra.Command {
	var name, privateKey string

	cmd := &cobra.Command{
		Use:   "import",
		Short: "Import an account from private key",
		RunE: func(cmd *cobra.Command, args []string) error {
			account, err := w.ImportAccount(name, privateKey)
			if err != nil {
				return err
			}

			fmt.Printf("Imported account:\n")
			fmt.Printf("Name: %s\n", account.Name)
			fmt.Printf("Address: %s\n", account.Address)

			return nil
		},
	}

	cmd.Flags().StringVar(&name, "name", "", "Account name (required)")
	cmd.Flags().StringVar(&privateKey, "private-key", "", "Private key hex (required)")
	cmd.MarkFlagRequired("name")
	cmd.MarkFlagRequired("private-key")

	return cmd
}

func listCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List all accounts",
		RunE: func(cmd *cobra.Command, args []string) error {
			accounts, err := w.ListAccounts()
			if err != nil {
				return err
			}

			if len(accounts) == 0 {
				fmt.Println("No accounts found")
				return nil
			}

			fmt.Printf("%-20s %s\n", "Name", "Address")
			fmt.Printf("%-20s %s\n", "----", "-------")
			for _, account := range accounts {
				fmt.Printf("%-20s %s\n", account.Name, account.Address)
			}

			return nil
		},
	}
}

func balanceCmd() *cobra.Command {
	var address, account string

	cmd := &cobra.Command{
		Use:   "balance",
		Short: "Get account balance",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Load account if specified
			if account != "" {
				if err := w.LoadAccount(account); err != nil {
					return err
				}
				address = ""
			}

			balance, err := w.GetBalance(address)
			if err != nil {
				return err
			}

			fmt.Printf("Balance: %d\n", balance)
			return nil
		},
	}

	cmd.Flags().StringVar(&address, "address", "", "Address to check")
	cmd.Flags().StringVar(&account, "account", "", "Account name to check")

	return cmd
}

func sendCmd() *cobra.Command {
	var to, account string
	var amount int64

	cmd := &cobra.Command{
		Use:   "send",
		Short: "Send tokens",
		RunE: func(cmd *cobra.Command, args []string) error {
			// If no account specified, try to use the first available account
			if account == "" {
				accounts, err := w.ListAccounts()
				if err != nil {
					return fmt.Errorf("failed to list accounts: %v", err)
				}
				if len(accounts) == 0 {
					return fmt.Errorf("no accounts found, please create an account first")
				}
				account = accounts[0].Name
			}

			if err := w.LoadAccount(account); err != nil {
				return err
			}

			txHash, err := w.SendTransaction(to, amount)
			if err != nil {
				return err
			}

			fmt.Printf("Transaction sent: %s\n", txHash)
			return nil
		},
	}

	cmd.Flags().StringVar(&to, "to", "", "Recipient address (required)")
	cmd.Flags().StringVar(&account, "account", "", "Sender account name (optional, uses first account if not specified)")
	cmd.Flags().Int64Var(&amount, "amount", 0, "Amount to send (required)")
	cmd.MarkFlagRequired("to")
	cmd.MarkFlagRequired("amount")

	return cmd
}

func receiveCmd() *cobra.Command {
	var account string

	cmd := &cobra.Command{
		Use:   "receive",
		Short: "Show receive address for account",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Load account
			if account == "" {
				return fmt.Errorf("account name required")
			}

			if err := w.LoadAccount(account); err != nil {
				return err
			}

			// Get account info to show address
			accounts, err := w.ListAccounts()
			if err != nil {
				return err
			}

			for _, acc := range accounts {
				if acc.Name == account {
					fmt.Printf("Receive Address: %s\n", acc.Address)
					fmt.Printf("Account: %s\n", acc.Name)
					return nil
				}
			}

			return fmt.Errorf("account not found: %s", account)
		},
	}

	cmd.Flags().StringVar(&account, "account", "", "Account name (required)")
	cmd.MarkFlagRequired("account")

	return cmd
}

func submitPatchCmd() *cobra.Command {
	var file, account, spec, code, codeHash string
	var gas int64

	cmd := &cobra.Command{
		Use:   "submit-patch",
		Short: "Submit a patch set",
		RunE: func(cmd *cobra.Command, args []string) error {
			// If no account specified, try to use the first available account
			if account == "" {
				accounts, err := w.ListAccounts()
				if err != nil {
					return fmt.Errorf("failed to list accounts: %v", err)
				}
				if len(accounts) == 0 {
					return fmt.Errorf("no accounts found, please create an account first")
				}
				account = accounts[0].Name
			}

			if err := w.LoadAccount(account); err != nil {
				return err
			}

			// Determine which file to use
			patchFile := file
			if code != "" {
				patchFile = code
			}

			if patchFile == "" {
				return fmt.Errorf("patch file required (use --file or --code)")
			}

			// Display submission details
			fmt.Printf("Submitting PatchSet:\n")
			fmt.Printf("  Spec: %s\n", spec)
			fmt.Printf("  Code: %s\n", patchFile)
			fmt.Printf("  Hash: %s\n", codeHash)
			fmt.Printf("  Gas: %d\n", gas)
			fmt.Printf("  Account: %s\n", account)
			fmt.Println()

			txHash, err := w.SubmitPatch(patchFile)
			if err != nil {
				return err
			}

			fmt.Printf("✅ Patch submitted successfully!\n")
			fmt.Printf("Transaction Hash: %s\n", txHash)
			fmt.Printf("The transaction will be packaged into the next block.\n")
			return nil
		},
	}

	cmd.Flags().StringVar(&file, "file", "", "Patch file path")
	cmd.Flags().StringVar(&account, "account", "", "Account name (optional, uses first account if not specified)")
	cmd.Flags().StringVar(&spec, "spec", "", "Specification ID (e.g., SYS-BOOTSTRAP-DEVNET-001)")
	cmd.Flags().StringVar(&code, "code", "", "Code package file path")
	cmd.Flags().StringVar(&codeHash, "code-hash", "", "SHA-256 hash of the code package")
	cmd.Flags().Int64Var(&gas, "gas", 50000, "Gas limit for the transaction")

	return cmd
}

func claimCmd() *cobra.Command {
	var account string
	var amount int64
	var check bool

	cmd := &cobra.Command{
		Use:   "claim",
		Short: "Claim available rewards",
		RunE: func(cmd *cobra.Command, args []string) error {
			// If no account specified, try to use the first available account
			if account == "" {
				accounts, err := w.ListAccounts()
				if err != nil {
					return fmt.Errorf("failed to list accounts: %v", err)
				}
				if len(accounts) == 0 {
					return fmt.Errorf("no accounts found, please create an account first")
				}
				account = accounts[0].Name
			}

			if err := w.LoadAccount(account); err != nil {
				return err
			}

			if check {
				// Check claimable amount
				claimable, err := w.GetClaimableRewards()
				if err != nil {
					return err
				}
				fmt.Printf("Claimable rewards for %s: %d tokens\n", account, claimable)
				return nil
			}

			// Claim rewards
			txHash, claimed, err := w.ClaimRewards(amount)
			if err != nil {
				return err
			}

			fmt.Printf("✅ Rewards claimed successfully!\n")
			fmt.Printf("Account: %s\n", account)
			fmt.Printf("Amount claimed: %d tokens\n", claimed)
			fmt.Printf("Transaction Hash: %s\n", txHash)
			return nil
		},
	}

	cmd.Flags().StringVar(&account, "account", "", "Account name (optional, uses first account if not specified)")
	cmd.Flags().Int64Var(&amount, "amount", 0, "Amount to claim (0 = claim all available)")
	cmd.Flags().BoolVar(&check, "check", false, "Check claimable amount without claiming")

	return cmd
}

func stakeCmd() *cobra.Command {
	var account, role string
	var amount int64
	var unstake bool

	cmd := &cobra.Command{
		Use:   "stake",
		Short: "Stake tokens to become a validator or delegate",
		RunE: func(cmd *cobra.Command, args []string) error {
			// If no account specified, try to use the first available account
			if account == "" {
				accounts, err := w.ListAccounts()
				if err != nil {
					return fmt.Errorf("failed to list accounts: %v", err)
				}
				if len(accounts) == 0 {
					return fmt.Errorf("no accounts found, please create an account first")
				}
				account = accounts[0].Name
			}

			if err := w.LoadAccount(account); err != nil {
				return err
			}

			if unstake {
				// Unstake tokens
				txHash, unstakedAmount, err := w.Unstake()
				if err != nil {
					return err
				}
				fmt.Printf("✅ Unstaking successful!\n")
				fmt.Printf("Account: %s\n", account)
				fmt.Printf("Amount unstaked: %d tokens\n", unstakedAmount)
				fmt.Printf("Transaction Hash: %s\n", txHash)
				fmt.Printf("Note: Unstaked tokens will be available after unbonding period\n")
				return nil
			}

			// Stake tokens
			txHash, err := w.Stake(amount, role)
			if err != nil {
				return err
			}

			fmt.Printf("✅ Staking successful!\n")
			fmt.Printf("Account: %s\n", account)
			fmt.Printf("Amount staked: %d tokens\n", amount)
			fmt.Printf("Role: %s\n", role)
			fmt.Printf("Transaction Hash: %s\n", txHash)

			if role == "validator" {
				fmt.Printf("\n🎉 Congratulations! You are now a validator!\n")
				fmt.Printf("📋 Validator Benefits:\n")
				fmt.Printf("  • Participate in consensus rounds\n")
				fmt.Printf("  • Earn block rewards for validation\n")
				fmt.Printf("  • Earn transaction fees\n")
				fmt.Printf("  • Additional staking rewards\n")
				fmt.Printf("\n📊 Your node will automatically join the next consensus round.\n")
			} else {
				fmt.Printf("\n💰 Delegation successful!\n")
				fmt.Printf("📋 Delegation Benefits:\n")
				fmt.Printf("  • Earn staking rewards\n")
				fmt.Printf("  • Support network security\n")
				fmt.Printf("  • No need to run validator node\n")
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&account, "account", "", "Account name (optional, uses first account if not specified)")
	cmd.Flags().Int64Var(&amount, "amount", 0, "Amount to stake (required for staking)")
	cmd.Flags().StringVar(&role, "role", "delegator", "Staking role: validator or delegator")
	cmd.Flags().BoolVar(&unstake, "unstake", false, "Unstake all staked tokens")

	return cmd
}

func heightCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "height",
		Short: "Get blockchain height",
		RunE: func(cmd *cobra.Command, args []string) error {
			height, err := w.GetHeight()
			if err != nil {
				return err
			}

			fmt.Printf("Height: %d\n", height)
			return nil
		},
	}
}

func getDefaultDataDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "./wallet-data"
	}
	return filepath.Join(home, ".agent-chain", "wallet")
}
