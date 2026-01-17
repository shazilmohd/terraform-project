# Backend configuration is passed dynamically from Jenkins via terraform init -backend-config flags
# This ensures:
# 1. Backend config is not hardcoded in version control
# 2. Same code works across dev/stage/prod
# 3. Sensitive values (if any) are not exposed in git history
#
# Jenkins will call:
# terraform init -backend-config="bucket=terraform-state-dev" \
#                -backend-config="key=dev/terraform.tfstate" \
#                -backend-config="region=ap-south-1" \
#                -backend-config="dynamodb_table=terraform-locks" \
#                -backend-config="encrypt=true"

terraform {
  backend "s3" {}
}
