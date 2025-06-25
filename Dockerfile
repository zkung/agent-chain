# Multi-stage build for Agent Chain
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make bash

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build binaries
RUN make build

# Final stage - minimal runtime image
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    bash \
    curl \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1000 agentchain && \
    adduser -D -s /bin/bash -u 1000 -G agentchain agentchain

# Set working directory
WORKDIR /app

# Copy binaries from builder
COPY --from=builder /app/bin/node /usr/local/bin/node
COPY --from=builder /app/bin/wallet /usr/local/bin/wallet

# Copy configuration templates
COPY --from=builder /app/configs /app/configs

# Create data directories
RUN mkdir -p /app/data /app/logs && \
    chown -R agentchain:agentchain /app

# Switch to non-root user
USER agentchain

# Expose ports
EXPOSE 8545 8546 8547 9001 9002 9003

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8545/health || exit 1

# Default command
CMD ["node", "--config", "/app/configs/node1.yaml"]
