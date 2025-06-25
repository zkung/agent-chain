# Agent Chain - Self-Evolving Task Chain (SETC)

A blockchain network driven by Large Language Models (LLM) that generates tasks and validates solutions through code submissions.

## Quick Start

### Prerequisites
- Go 1.21+
- Docker (optional)
- Git

### One-Click DevNet Setup

**Linux/macOS:**
```bash
./bootstrap.sh
```

**Windows:**
```powershell
.\bootstrap.ps1
```

This will:
1. Build the blockchain node and CLI wallet
2. Generate keys for 3 nodes
3. Start a local 3-node testnet
4. Provide CLI wallet for basic operations

### CLI Wallet Usage

```bash
# Create new account
./wallet new --name alice

# Check balance
./wallet balance --address <address>

# Send transaction
./wallet send --to <address> --amount <amount>

# Submit PatchSet
./wallet submit-patch --file <patch.json>

# Check block height
./wallet height --rpc 127.0.0.1:8545
```

## Architecture

```
├── cmd/
│   ├── node/          # Blockchain node binary
│   └── wallet/        # CLI wallet binary
├── pkg/
│   ├── blockchain/    # Core blockchain logic
│   ├── consensus/     # PoE consensus mechanism
│   ├── network/       # P2P networking
│   ├── wallet/        # Wallet functionality
│   └── types/         # Data structures
├── configs/           # Configuration files
├── scripts/           # Bootstrap scripts
└── tests/            # Test suites
```

## Features

- **Proof-of-Evolution (PoE)**: Consensus based on code submissions
- **PatchSet Transactions**: Submit code patches as blockchain transactions
- **Multi-node Testnet**: Local 3-node network for development
- **CLI Wallet**: Complete wallet functionality
- **Cross-platform**: Supports Linux, macOS, and Windows

## Development

```bash
# Build all binaries
make build

# Run tests
make test

# Start single node
./bin/node --config configs/node1.yaml

# Start wallet
./bin/wallet --help
```

## Resource Requirements

- **Memory**: ≤ 1GB peak usage
- **Storage**: ≤ 800MB for Docker images
- **Network**: Local testnet only
- **Time**: ≤ 5 minutes for full bootstrap

## License

MIT License - see LICENSE file for details.
