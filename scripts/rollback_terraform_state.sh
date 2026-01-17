#!/bin/bash

################################################################################
# Terraform State Rollback Script
#
# Purpose: Rollback Terraform state from a backup file to S3
# Usage: ./scripts/rollback_terraform_state.sh <environment> <backup_file>
#
# Examples:
#   ./scripts/rollback_terraform_state.sh dev .terraform-backups/terraform-dev-20260117_100000.tfstate
#   ./scripts/rollback_terraform_state.sh prod .terraform-backups/terraform-prod-20260116_150000.tfstate
#   ./scripts/rollback_terraform_state.sh stage .terraform-backups/terraform-stage-20260115_120000.tfstate
#
# Requirements:
#   - AWS CLI configured with appropriate credentials
#   - S3 bucket: terraform-state-1768505102
#   - Backup file must exist and be valid JSON
#   - User confirmation (type "ROLLBACK" to proceed)
#
# Safety Features:
#   - Validates environment directory exists
#   - Validates backup file exists and is valid JSON
#   - Requires explicit user confirmation
#   - Creates pre-rollback backup
#   - Logs all operations for audit trail
#
# Output:
#   - Uploads backup to S3 (overwrites current state)
#   - Prints instructions for next steps
#   - Logs rollback operation to git
#
################################################################################

set -e

# Configuration
BUCKET_NAME="terraform-state-1768505102"
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

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
}

# Parse arguments
ENVIRONMENT=$1
BACKUP_FILE=$2

# Validate arguments
if [ -z "$ENVIRONMENT" ] || [ -z "$BACKUP_FILE" ]; then
    log_error "Usage: $0 <environment> <backup_file>"
    log_info ""
    log_info "Examples:"
    echo "  $0 dev .terraform-backups/terraform-dev-20260117_100000.tfstate"
    echo "  $0 prod .terraform-backups/terraform-prod-20260116_150000.tfstate"
    exit 1
fi

# Validate environment directory exists
if [ ! -d "env/$ENVIRONMENT" ]; then
    log_error "Environment directory not found: env/$ENVIRONMENT"
    log_info "Valid environments: dev, stage, prod"
    exit 1
fi

# Validate backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Backup file not found: $BACKUP_FILE"
    log_info ""
    log_info "Available backups:"
    if [ -d ".terraform-backups" ]; then
        ls -lah .terraform-backups/ | tail -10
    else
        log_warning "No .terraform-backups directory found"
    fi
    exit 1
fi

# Validate backup file is valid JSON
if ! jq empty "$BACKUP_FILE" 2>/dev/null; then
    log_error "Backup file is not valid JSON: $BACKUP_FILE"
    exit 1
fi

# Extract metadata from backup
BACKUP_SERIAL=$(jq -r '.serial' "$BACKUP_FILE")
BACKUP_LINEAGE=$(jq -r '.lineage' "$BACKUP_FILE")
BACKUP_RESOURCES=$(jq -r '.resources | length' "$BACKUP_FILE")
BACKUP_VERSION=$(jq -r '.terraform_version' "$BACKUP_FILE")

# Get current state info from S3
log_info "Retrieving current state information from S3..."
CURRENT_STATE="/tmp/current-state-$ENVIRONMENT.tfstate"

if aws s3 cp "s3://${BUCKET_NAME}/${ENVIRONMENT}/terraform.tfstate" "$CURRENT_STATE" 2>/dev/null; then
    CURRENT_SERIAL=$(jq -r '.serial' "$CURRENT_STATE")
    CURRENT_RESOURCES=$(jq -r '.resources | length' "$CURRENT_STATE")
    CURRENT_VERSION=$(jq -r '.terraform_version' "$CURRENT_STATE")
    
    log_info "Current state serial: $CURRENT_SERIAL"
    log_info "Current resource count: $CURRENT_RESOURCES"
else
    log_warning "Could not retrieve current state (may not exist yet)"
    CURRENT_SERIAL="N/A"
    CURRENT_RESOURCES="N/A"
fi

# Display confirmation prompt
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          TERRAFORM STATE ROLLBACK - CONFIRMATION               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
log_critical "This operation will RESTORE an older Terraform state."
log_critical "The next 'terraform apply' will MODIFY or DELETE resources to match the old state."
echo ""
echo "Environment:            $ENVIRONMENT"
echo "Backup File:            $BACKUP_FILE"
echo ""
echo "Backup Information:"
echo "  Serial:               $BACKUP_SERIAL"
echo "  Resource Count:       $BACKUP_RESOURCES"
echo "  Terraform Version:    $BACKUP_VERSION"
echo ""
echo "Current State (in S3):"
echo "  Serial:               $CURRENT_SERIAL"
echo "  Resource Count:       $CURRENT_RESOURCES"
echo "  Terraform Version:    $CURRENT_VERSION"
echo ""
echo "⚠️  IMPORTANT:"
echo "  1. This will OVERWRITE the current state in S3"
echo "  2. You MUST run 'terraform apply' to reconcile infrastructure"
echo "  3. Review 'terraform plan' output before applying"
echo "  4. This action CANNOT be undone (ensure backup exists)"
echo ""
read -p "Type 'ROLLBACK' to proceed (case-sensitive): " confirmation

if [ "$confirmation" != "ROLLBACK" ]; then
    log_info "Rollback cancelled by user"
    rm -f "$CURRENT_STATE"
    exit 0
fi

# Create pre-rollback backup
log_info ""
log_info "Creating pre-rollback backup (safety measure)..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PRE_ROLLBACK_BACKUP=".terraform-backups/terraform-${ENVIRONMENT}-pre-rollback-${TIMESTAMP}.tfstate"

mkdir -p ".terraform-backups"
cp "$CURRENT_STATE" "$PRE_ROLLBACK_BACKUP"
log_success "Pre-rollback backup created: $PRE_ROLLBACK_BACKUP"

# Upload backup file to S3
log_info ""
log_info "Uploading rollback state to S3..."

if aws s3 cp "$BACKUP_FILE" "s3://${BUCKET_NAME}/${ENVIRONMENT}/terraform.tfstate"; then
    log_success "State successfully uploaded to S3"
else
    log_error "Failed to upload state to S3"
    log_critical "Rollback FAILED. Current state is unchanged."
    exit 1
fi

# Verify upload
log_info "Verifying uploaded state..."
VERIFY_STATE="/tmp/verify-state-$ENVIRONMENT.tfstate"

if aws s3 cp "s3://${BUCKET_NAME}/${ENVIRONMENT}/terraform.tfstate" "$VERIFY_STATE" 2>/dev/null; then
    if jq empty "$VERIFY_STATE" 2>/dev/null; then
        VERIFY_SERIAL=$(jq -r '.serial' "$VERIFY_STATE")
        VERIFY_RESOURCES=$(jq -r '.resources | length' "$VERIFY_STATE")
        log_success "Verification successful"
        log_info "  New serial: $VERIFY_SERIAL"
        log_info "  Resource count: $VERIFY_RESOURCES"
    else
        log_error "Uploaded state is invalid JSON"
        exit 1
    fi
else
    log_error "Could not verify uploaded state"
    exit 1
fi

# Cleanup temp files
rm -f "$CURRENT_STATE" "$VERIFY_STATE"

# Log rollback operation to git
log_info ""
log_info "Logging rollback operation to git..."

cd "$PROJECT_ROOT"

cat >> ".terraform-rollback-log.txt" <<EOF
Rollback Operation Log Entry
============================
Timestamp: $(date)
Environment: $ENVIRONMENT
Backup File: $BACKUP_FILE
Backup Serial: $BACKUP_SERIAL
Pre-Rollback Backup: $PRE_ROLLBACK_BACKUP
Status: SUCCESS

---
EOF

git add ".terraform-backups" ".terraform-rollback-log.txt" 2>/dev/null || true
git commit -m "Rollback: $ENVIRONMENT state reverted to serial $BACKUP_SERIAL" 2>/dev/null || true

# Print next steps
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    ROLLBACK SUCCESSFUL                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
log_success "State successfully rolled back"
echo ""
echo "📋 NEXT STEPS:"
echo ""
echo "1️⃣  Review infrastructure changes:"
echo "    cd env/$ENVIRONMENT"
echo "    terraform plan -var-file=terraform.tfvars"
echo ""
echo "2️⃣  Reconcile infrastructure (when ready):"
echo "    cd env/$ENVIRONMENT"
echo "    terraform apply -auto-approve"
echo ""
echo "3️⃣  Verify resources:"
echo "    aws ec2 describe-instances --filters Name=tag:Environment,Values=$ENVIRONMENT"
echo ""
echo "⚠️  ROLLBACK INFORMATION:"
echo "    - Current state: s3://${BUCKET_NAME}/${ENVIRONMENT}/terraform.tfstate"
echo "    - Pre-rollback backup: $PRE_ROLLBACK_BACKUP"
echo "    - Rollback log: .terraform-rollback-log.txt"
echo ""
echo "🔙 To undo this rollback:"
echo "    ./scripts/rollback_terraform_state.sh $ENVIRONMENT $PRE_ROLLBACK_BACKUP"
echo ""

exit 0
