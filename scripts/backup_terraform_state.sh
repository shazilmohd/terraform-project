#!/bin/bash

################################################################################
# Terraform State Backup Script
# 
# Purpose: Backup current Terraform state from S3 to local .terraform-backups/
# Usage: ./scripts/backup_terraform_state.sh [environment]
# Examples:
#   ./scripts/backup_terraform_state.sh          # Backup all environments
#   ./scripts/backup_terraform_state.sh dev      # Backup only dev
#   ./scripts/backup_terraform_state.sh prod     # Backup only prod
#
# Requirements:
#   - AWS CLI configured with appropriate credentials
#   - S3 bucket: terraform-state-1768505102
#   - DynamoDB table: terraform-locks
#
# Output:
#   - Backups stored in: .terraform-backups/terraform-{env}-{timestamp}.tfstate
#   - Committed to git for audit trail
#
################################################################################

set -e

# Configuration
BUCKET_NAME="terraform-state-1768505102"
BACKUP_DIR=".terraform-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Determine which environments to backup
if [ -z "$1" ]; then
    ENVIRONMENTS=("dev" "stage" "prod")
    log_info "No environment specified. Backing up all environments..."
else
    ENVIRONMENTS=("$1")
    log_info "Backing up environment: $1"
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log_info "Backup directory: $BACKUP_DIR"
log_info "Timestamp: $TIMESTAMP"
log_info "S3 Bucket: $BUCKET_NAME"
echo ""

# Counter for statistics
BACKUP_COUNT=0
FAILED_COUNT=0

# Backup each environment
for env in "${ENVIRONMENTS[@]}"; do
    log_info "Backing up $env environment..."
    
    BACKUP_FILE="${BACKUP_DIR}/terraform-${env}-${TIMESTAMP}.tfstate"
    S3_PATH="s3://${BUCKET_NAME}/${env}/terraform.tfstate"
    
    # Download state from S3
    if aws s3 cp "$S3_PATH" "$BACKUP_FILE" 2>/dev/null; then
        # Verify the backup file was created and is valid JSON
        if [ -f "$BACKUP_FILE" ] && jq empty "$BACKUP_FILE" 2>/dev/null; then
            FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
            log_success "Backed up $env state (${FILE_SIZE})"
            log_info "  File: $BACKUP_FILE"
            
            # Get serial number for audit
            SERIAL=$(jq -r '.serial' "$BACKUP_FILE")
            log_info "  State serial: $SERIAL"
            
            BACKUP_COUNT=$((BACKUP_COUNT + 1))
        else
            log_error "Backup file validation failed for $env"
            rm -f "$BACKUP_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    else
        log_error "Failed to download state from S3 for $env"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    
    echo ""
done

# Summary
log_info "========== BACKUP SUMMARY =========="
log_success "Successful backups: $BACKUP_COUNT"
if [ $FAILED_COUNT -gt 0 ]; then
    log_warning "Failed backups: $FAILED_COUNT"
fi

# Offer to commit to git
if [ $BACKUP_COUNT -gt 0 ]; then
    echo ""
    log_info "Committing backups to git for audit trail..."
    
    cd "$PROJECT_ROOT"
    
    # Check if there are changes to commit
    if [ -n "$(git status --porcelain "$BACKUP_DIR")" ]; then
        git add "$BACKUP_DIR"
        git commit -m "State backup: $TIMESTAMP (${BACKUP_COUNT} environment(s))" || true
        
        # Try to push (might fail if no remote configured)
        if git push origin HEAD:main 2>/dev/null || git push 2>/dev/null; then
            log_success "Backups committed and pushed to git"
        else
            log_warning "Backups committed locally but could not push to remote"
        fi
    else
        log_warning "No changes to commit (backups may already be in git)"
    fi
fi

echo ""
if [ $FAILED_COUNT -eq 0 ]; then
    log_success "Backup process completed successfully"
    exit 0
else
    log_error "Backup process completed with errors"
    exit 1
fi
