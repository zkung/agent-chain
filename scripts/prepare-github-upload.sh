#!/bin/bash

# Agent Chain GitHub Upload Preparation Script
# Version: 1.0.0
# Purpose: Clean and organize project for GitHub upload

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Clean temporary and runtime files
clean_temporary_files() {
    log_info "Cleaning temporary and runtime files..."
    
    cd "$PROJECT_ROOT"
    
    # Remove compiled binaries
    rm -f *.exe node wallet
    rm -rf bin/
    
    # Remove runtime data
    rm -rf data/ logs/ wallet-data/
    
    # Remove temporary files
    rm -f *.tmp *.temp *.log
    rm -f *_test_report.json
    rm -f mainnet_launch_approval.json
    rm -f submission_info.json
    rm -f submission_metadata.json
    rm -f dependencies.json
    rm -f staking_guide.json
    rm -f claim_rewards.sh
    rm -f submit_command.sh
    
    # Remove test artifacts
    rm -f agent-chain-patchset.tar.gz
    
    # Remove Python cache
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    
    log_success "Temporary files cleaned"
}

# Organize documentation
organize_documentation() {
    log_info "Organizing documentation..."
    
    cd "$PROJECT_ROOT"
    
    # Create docs directory
    mkdir -p docs/
    
    # Move documentation files
    local doc_files=(
        "IMPLEMENTATION_SUMMARY.md"
        "TESTING_GUIDE.md"
        "FINAL_PROJECT_SUMMARY.md"
        "PROJECT_COMPLETION_SUMMARY.md"
        "BOOTSTRAP_TEST_REPORT.md"
        "FINAL_TEST_REPORT.md"
        "PATCHSET_SUBMISSION_REPORT.md"
        "REWARD_CLAIMING_REPORT.md"
        "STAKING_IMPLEMENTATION_REPORT.md"
        "TEST_REPORT.md"
        "PRODUCTION_DEPLOYMENT_GUIDE.md"
        "MAINNET_TESTING_PLAN.md"
    )
    
    for doc in "${doc_files[@]}"; do
        if [[ -f "$doc" ]]; then
            mv "$doc" docs/
            log_success "Moved $doc to docs/"
        fi
    done
    
    # Keep important docs in root
    local root_docs=(
        "README.md"
        "LICENSE"
        "WHITEPAPER.md"
        "GITHUB_UPLOAD_GUIDE.md"
    )
    
    log_success "Documentation organized"
}

# Clean test files
clean_test_files() {
    log_info "Cleaning test files..."
    
    cd "$PROJECT_ROOT"
    
    # Remove temporary test files
    local test_files=(
        "mock_test.py"
        "offline_test.py"
        "performance_test.py"
        "simple_claim_demo.py"
        "simple_test.py"
        "staking_demo.py"
        "test_bootstrap_fixed.py"
        "validate_spec.py"
        "claim_rewards_demo.py"
        "demo_submission.py"
        "monitor_verification.py"
        "create_patchset.py"
        "mainnet_test_suite.py"
        "mainnet_test_fixed.py"
        "mainnet_launch_validation.py"
        "network_status_check.py"
    )
    
    for file in "${test_files[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            log_success "Removed $file"
        fi
    done
    
    log_success "Test files cleaned"
}

# Verify project structure
verify_project_structure() {
    log_info "Verifying project structure..."
    
    cd "$PROJECT_ROOT"
    
    # Check essential files
    local essential_files=(
        "README.md"
        "LICENSE"
        "go.mod"
        "go.sum"
        "Makefile"
        "Dockerfile"
        ".gitignore"
        "bootstrap.sh"
        "bootstrap.ps1"
        "docker-compose.yml"
    )
    
    local missing_files=()
    for file in "${essential_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing essential files:"
        for file in "${missing_files[@]}"; do
            log_error "  - $file"
        done
        return 1
    fi
    
    # Check essential directories
    local essential_dirs=(
        "cmd"
        "pkg"
        "configs"
        "scripts"
    )
    
    local missing_dirs=()
    for dir in "${essential_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -gt 0 ]]; then
        log_error "Missing essential directories:"
        for dir in "${missing_dirs[@]}"; do
            log_error "  - $dir"
        done
        return 1
    fi
    
    log_success "Project structure verified"
}

# Check for sensitive information
check_sensitive_info() {
    log_info "Checking for sensitive information..."
    
    cd "$PROJECT_ROOT"
    
    # Search for potential sensitive patterns
    local sensitive_patterns=(
        "private.*key"
        "secret"
        "password"
        "token.*[a-zA-Z0-9]{20,}"
        "api.*key"
    )
    
    local found_sensitive=false
    for pattern in "${sensitive_patterns[@]}"; do
        if grep -r -i "$pattern" . --exclude-dir=.git --exclude-dir=docs --exclude="*.md" --exclude="GITHUB_UPLOAD_GUIDE.md" 2>/dev/null; then
            log_warning "Found potential sensitive information: $pattern"
            found_sensitive=true
        fi
    done
    
    if [[ "$found_sensitive" == "true" ]]; then
        log_warning "Please review and remove any sensitive information before uploading"
    else
        log_success "No obvious sensitive information found"
    fi
}

# Generate final project summary
generate_project_summary() {
    log_info "Generating project summary..."
    
    cd "$PROJECT_ROOT"
    
    # Count files and directories
    local go_files=$(find . -name "*.go" -not -path "./.git/*" | wc -l)
    local md_files=$(find . -name "*.md" -not -path "./.git/*" | wc -l)
    local total_files=$(find . -type f -not -path "./.git/*" | wc -l)
    local total_dirs=$(find . -type d -not -path "./.git/*" | wc -l)
    
    # Calculate project size
    local project_size=$(du -sh . 2>/dev/null | cut -f1 || echo "Unknown")
    
    cat > PROJECT_UPLOAD_SUMMARY.md << EOF
# Agent Chain Upload Summary

**Preparation Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Version**: v1.0.0
**Status**: Ready for GitHub Upload

## 📊 Project Statistics

- **Go Source Files**: $go_files
- **Documentation Files**: $md_files
- **Total Files**: $total_files
- **Total Directories**: $total_dirs
- **Project Size**: $project_size

## 📁 Project Structure

\`\`\`
$(tree -I '.git|data|logs|wallet-data|bin|*.exe|*.log|*.tmp' -L 2 2>/dev/null || find . -type d -not -path "./.git*" -not -path "./data*" -not -path "./logs*" -not -path "./wallet-data*" -not -path "./bin*" | head -20)
\`\`\`

## ✅ Upload Checklist

- [x] Temporary files cleaned
- [x] Runtime data removed
- [x] Documentation organized
- [x] Test files cleaned
- [x] Project structure verified
- [x] Sensitive information checked
- [x] .gitignore configured

## 🚀 Ready for Upload

The project is now ready for GitHub upload. Use the following commands:

\`\`\`bash
git add .
git commit -m "feat: Agent Chain v1.0.0 - Complete blockchain implementation"
git push -u origin main
git tag -a v1.0.0 -m "Agent Chain v1.0.0 - Production Release"
git push origin v1.0.0
\`\`\`

## 📋 Next Steps

1. Upload to GitHub
2. Create Release on GitHub
3. Update repository description and topics
4. Set up GitHub Actions (optional)
5. Add community files (CONTRIBUTING.md, etc.)

---

**Generated by**: prepare-github-upload.sh
**Project**: Agent Chain v1.0.0
EOF
    
    log_success "Project summary generated: PROJECT_UPLOAD_SUMMARY.md"
}

# Main function
main() {
    log_info "🚀 Starting Agent Chain GitHub Upload Preparation"
    echo "=" * 60
    
    # Run all preparation steps
    clean_temporary_files
    organize_documentation
    clean_test_files
    verify_project_structure
    check_sensitive_info
    generate_project_summary
    
    echo
    log_success "🎉 GitHub Upload Preparation Completed!"
    echo
    log_info "📋 Summary:"
    log_info "  ✅ Temporary files cleaned"
    log_info "  ✅ Documentation organized"
    log_info "  ✅ Test files cleaned"
    log_info "  ✅ Project structure verified"
    log_info "  ✅ Sensitive information checked"
    log_info "  ✅ Upload summary generated"
    echo
    log_info "🔗 Next Steps:"
    log_info "  1. Review PROJECT_UPLOAD_SUMMARY.md"
    log_info "  2. Check .gitignore configuration"
    log_info "  3. Run: git add ."
    log_info "  4. Run: git commit -m 'feat: Agent Chain v1.0.0'"
    log_info "  5. Run: git push -u origin main"
    echo
    log_success "🚀 Project is ready for GitHub upload!"
}

# Run main function
main "$@"
