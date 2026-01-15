#!/bin/bash

# Load Jenkins configuration
# This script loads external configuration from jenkins.env file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/jenkins.env"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: jenkins.env configuration file not found at $CONFIG_FILE"
    echo "Please create jenkins.env with required configuration values"
    exit 1
fi

# Load configuration
source "$CONFIG_FILE"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Jenkins Pipeline Configuration Loaded                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Git Configuration:"
echo "  Repository: $GIT_REPO_URL"
echo "  Branch: $GIT_BRANCH"
echo ""
echo "Jenkins Configuration:"
echo "  Approvers: $JENKINS_APPROVERS"
echo "  Notification Email: $JENKINS_NOTIFY_EMAIL"
echo ""
echo "AWS Configuration:"
echo "  Region: $AWS_REGION"
echo "  Credentials ID: $AWS_CREDENTIALS_ID"
echo ""
echo "Terraform Configuration:"
echo "  Version: $TERRAFORM_VERSION"
echo "  Log Level: $TF_LOG_LEVEL"
echo ""
echo "Supported Environments: $SUPPORTED_ENVIRONMENTS"
echo ""

# Validate critical configurations
if [ -z "$GIT_REPO_URL" ]; then
    echo "Error: GIT_REPO_URL not configured in jenkins.env"
    exit 1
fi

if [ -z "$AWS_REGION" ]; then
    echo "Error: AWS_REGION not configured in jenkins.env"
    exit 1
fi

echo "✓ Configuration validation successful"
