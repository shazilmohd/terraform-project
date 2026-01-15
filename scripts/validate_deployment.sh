#!/bin/bash

# Pre-deployment validation script
# This script validates the Terraform configuration before Jenkins pipeline execution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="env/dev"
ENVIRONMENT="dev"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Terraform Pre-Deployment Validation - ${ENVIRONMENT}      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation functions
check_command() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        local version=$("$cmd" version 2>/dev/null | head -1 || "$cmd" --version 2>/dev/null | head -1)
        echo -e "${GREEN}✓${NC} $name installed: $version"
        return 0
    else
        echo -e "${RED}✗${NC} $name not found. Please install $name."
        return 1
    fi
}

check_file_exists() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description found: $file"
        return 0
    else
        echo -e "${RED}✗${NC} $description not found: $file"
        return 1
    fi
}

check_directory_exists() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description exists: $dir"
        return 0
    else
        echo -e "${RED}✗${NC} $description not found: $dir"
        return 1
    fi
}

# 1. Check required commands
echo -e "${BLUE}[1/6]${NC} Checking required tools..."
check_command "terraform" "Terraform" || exit 1
check_command "aws" "AWS CLI" || exit 1
check_command "git" "Git" || exit 1
echo ""

# 2. Check directory structure
echo -e "${BLUE}[2/6]${NC} Checking directory structure..."
check_directory_exists "$TF_DIR" "Terraform directory (env/dev)" || exit 1
check_directory_exists "modules" "Modules directory" || exit 1
check_directory_exists "modules/networking/vpc" "VPC module" || exit 1
check_directory_exists "modules/networking/security_group" "Security Group module" || exit 1
check_directory_exists "modules/compute/ec2" "EC2 module" || exit 1
check_directory_exists "modules/secrets/secret_manager" "Secrets Manager module" || exit 1
echo ""

# 3. Check terraform files
echo -e "${BLUE}[3/6]${NC} Checking Terraform configuration files..."
check_file_exists "env/dev/main.tf" "Dev main.tf" || exit 1
check_file_exists "env/dev/variables.tf" "Dev variables.tf" || exit 1
check_file_exists "env/dev/outputs.tf" "Dev outputs.tf" || exit 1
check_file_exists "env/dev/terraform.tfvars" "Dev terraform.tfvars" || exit 1
echo ""

# 4. Check AWS credentials
echo -e "${BLUE}[4/6]${NC} Checking AWS credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CALLER_ID=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓${NC} AWS credentials configured"
    echo "  Account ID: $ACCOUNT_ID"
    echo "  Caller Identity: $CALLER_ID"
else
    echo -e "${RED}✗${NC} AWS credentials not configured or invalid"
    exit 1
fi
echo ""

# 5. Check Secrets Manager
echo -e "${BLUE}[5/6]${NC} Checking AWS Secrets Manager..."
SECRETS_NAME=$(grep "secrets_manager_secret_name" env/dev/terraform.tfvars | grep -oP '=\s*"\K[^"]+')
if [ -n "$SECRETS_NAME" ]; then
    if aws secretsmanager describe-secret --secret-id "$SECRETS_NAME" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Secrets Manager secret found: $SECRETS_NAME"
    else
        echo -e "${YELLOW}⚠${NC} Warning: Secrets Manager secret not found: $SECRETS_NAME"
        echo "  Create it with: aws secretsmanager create-secret --name $SECRETS_NAME --secret-string '{...}'"
    fi
else
    echo -e "${YELLOW}⚠${NC} Warning: Secrets Manager secret name not configured"
fi
echo ""

# 6. Validate Terraform syntax
echo -e "${BLUE}[6/6]${NC} Validating Terraform syntax..."
cd "$TF_DIR"

if terraform validate > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Terraform configuration is valid"
else
    echo -e "${RED}✗${NC} Terraform validation failed:"
    terraform validate
    exit 1
fi

# Format check
echo ""
echo "Checking Terraform formatting..."
if terraform fmt -check -recursive ../.. > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Terraform formatting is correct"
else
    echo -e "${YELLOW}⚠${NC} Some Terraform files are not formatted correctly"
    echo "  Run 'terraform fmt -recursive' to auto-format"
fi

cd "$SCRIPT_DIR"
echo ""

# Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Validation Summary - ALL CHECKS PASSED           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✓ Ready for Jenkins pipeline deployment${NC}"
echo ""
echo "Next steps:"
echo "  1. Review terraform.tfvars configuration"
echo "  2. Commit changes to git repository"
echo "  3. Trigger Jenkins pipeline"
echo "  4. Approve terraform apply when prompted"
echo ""
