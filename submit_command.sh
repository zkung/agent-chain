# Submit PatchSet using CLI wallet
./wallet.exe submit-patch \
    --spec SYS-BOOTSTRAP-DEVNET-001 \
    --code agent-chain-patchset.tar.gz \
    --code-hash f7bbd8c325574880d5b2c0b398c5fcbfedc580b44615aea8b044b8fcd965a87a \
    --gas 50000 \
    --account <your-account-name>

# Alternative with explicit parameters
./wallet.exe submit-patch \
    --file agent-chain-patchset.tar.gz \
    --account <your-account-name>
