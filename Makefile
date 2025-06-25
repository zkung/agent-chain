.PHONY: build clean test deps node wallet bootstrap

# Build configuration
BINARY_DIR := bin
NODE_BINARY := $(BINARY_DIR)/node
WALLET_BINARY := $(BINARY_DIR)/wallet
GO_FILES := $(shell find . -name "*.go" -type f)

# Default target
all: deps build

# Install dependencies
deps:
	go mod download
	go mod tidy

# Build all binaries
build: $(NODE_BINARY) $(WALLET_BINARY)

# Build node binary
$(NODE_BINARY): $(GO_FILES)
	@mkdir -p $(BINARY_DIR)
	go build -o $(NODE_BINARY) ./cmd/node

# Build wallet binary  
$(WALLET_BINARY): $(GO_FILES)
	@mkdir -p $(BINARY_DIR)
	go build -o $(WALLET_BINARY) ./cmd/wallet

# Build node only
node: $(NODE_BINARY)

# Build wallet only
wallet: $(WALLET_BINARY)

# Run tests
test:
	go test -v ./...

# Run bootstrap script
bootstrap: build
	@if [ "$(OS)" = "Windows_NT" ]; then \
		powershell -ExecutionPolicy Bypass -File bootstrap.ps1; \
	else \
		bash bootstrap.sh; \
	fi

# Clean build artifacts
clean:
	rm -rf $(BINARY_DIR)
	rm -rf data/
	rm -rf logs/
	go clean

# Format code
fmt:
	go fmt ./...

# Lint code
lint:
	golangci-lint run

# Generate documentation
docs:
	godoc -http=:6060

# Docker build
docker-build:
	docker build -t agent-chain:latest .

# Docker compose up
docker-up:
	docker-compose up -d

# Docker compose down
docker-down:
	docker-compose down

# Help
help:
	@echo "Available targets:"
	@echo "  build      - Build all binaries"
	@echo "  node       - Build node binary only"
	@echo "  wallet     - Build wallet binary only"
	@echo "  test       - Run tests"
	@echo "  bootstrap  - Run bootstrap script"
	@echo "  clean      - Clean build artifacts"
	@echo "  fmt        - Format code"
	@echo "  lint       - Lint code"
	@echo "  docs       - Start documentation server"
	@echo "  docker-*   - Docker related commands"
	@echo "  help       - Show this help"
