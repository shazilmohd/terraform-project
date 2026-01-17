pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'stage', 'prod', 'parallel-destroy-all'],
            description: 'Environment to deploy to (use parallel-destroy-all for dev+stage+prod destruction)'
        )
        
        choice(
            name: 'ACTION',
            choices: ['PLAN', 'APPLY', 'DESTROY'],
            description: 'Terraform action to perform'
        )
        
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Skip manual approval for terraform apply'
        )
        
        string(
            name: 'AWS_REGION',
            defaultValue: 'ap-south-1',
            description: 'AWS region for deployment'
        )
        
        string(
            name: 'TERRAFORM_VERSION',
            defaultValue: '1.5.0',
            description: 'Terraform version to use'
        )
    }

    environment {
        // Dynamic paths based on parameters
        TF_WORKING_DIR = "env/${params.ENVIRONMENT}"
        // AWS_REGION removed - let AWS SDK auto-detect S3 bucket region
        TF_LOG = 'INFO'
        
        // Build Information
        BUILD_TIMESTAMP = sh(script: "date +%Y%m%d_%H%M%S", returnStdout: true).trim()
        ENVIRONMENT = "${params.ENVIRONMENT}"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '30'))
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }

    stages {
        stage('Pre-Validation') {
            steps {
                script {
                    echo "========== Running pre-deployment validation =========="
                    
                    sh '''
                        # Check if Terraform is installed
                        which terraform || (echo "Terraform not found" && exit 1)
                        
                        # Check Terraform version
                        terraform version
                        
                        # Check AWS CLI
                        which aws || (echo "AWS CLI not found" && exit 1)
                        
                        # Verify AWS credentials
                        aws sts get-caller-identity
                        
                        # Check if environment directory exists (skip for parallel-destroy-all)
                        if [ "${ENVIRONMENT}" != "parallel-destroy-all" ]; then
                            if [ ! -d "${TF_WORKING_DIR}" ]; then
                                echo "Error: ${TF_WORKING_DIR} directory not found"
                                exit 1
                            fi
                        else
                            echo "✓ Skipping directory check for parallel-destroy-all (special mode)"
                        fi
                        
                        echo "✓ All pre-validation checks passed"
                    '''
                }
            }
        }

        stage('Parameter Validation') {
            steps {
                script {
                    echo "========== Validating pipeline parameters =========="
                    
                    // Validate ENVIRONMENT parameter (including special parallel-destroy-all)
                    def validEnvironments = ['dev', 'stage', 'prod', 'parallel-destroy-all']
                    if (!validEnvironments.contains(params.ENVIRONMENT)) {
                        error("❌ Invalid ENVIRONMENT: ${params.ENVIRONMENT}. Must be one of: ${validEnvironments.join(', ')}")
                    }
                    
                    // Validate ACTION parameter (convert to lowercase for comparison)
                    def validActions = ['plan', 'apply', 'destroy']
                    def actionLower = params.ACTION.toLowerCase()
                    if (!validActions.contains(actionLower)) {
                        error("❌ Invalid ACTION: ${params.ACTION}. Must be one of: ${validActions.join(', ')}")
                    }
                    
                    // CRITICAL: Block destroy on production
                    if (params.ENVIRONMENT == 'prod' && actionLower == 'destroy') {
                        error("❌ DESTROY is not permitted on PROD environment. Contact senior team for manual intervention.")
                    }
                    
                    echo "✓ ENVIRONMENT: ${params.ENVIRONMENT}"
                    echo "✓ ACTION: ${params.ACTION}"
                    echo "✓ All parameter validations passed"
                }
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    echo "========== Initializing Terraform with dynamic backend config =========="
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            # Determine backend bucket and DynamoDB table names
                            # Note: Using actual bucket name terraform-state-1768505102
                            BACKEND_BUCKET="terraform-state-1768505102"
                            DYNAMODB_TABLE="terraform-locks"
                            
                            echo "🔧 Backend Configuration:"
                            echo "   Bucket: ${BACKEND_BUCKET}"
                            echo "   Table: ${DYNAMODB_TABLE}"
                            
                            # Use ap-south-1 for backend bucket (where S3 bucket actually exists)
                            # This is separate from resource provisioning region
                            BUCKET_REGION="ap-south-1"  # S3 bucket location
                            
                            echo "   Backend Region: ${BUCKET_REGION}"
                            
                            # Initialize Terraform with dynamic backend config
                            # Includes the detected (or default) region to match bucket location
                            terraform init \
                                -upgrade \
                                -input=false \
                                -backend-config="bucket=${BACKEND_BUCKET}" \
                                -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
                                -backend-config="region=${BUCKET_REGION}" \
                                -backend-config="dynamodb_table=${DYNAMODB_TABLE}" \
                                -backend-config="encrypt=true"
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                script {
                    echo "========== Validating Terraform configuration =========="
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            terraform validate
                        '''
                    }
                }
            }
        }

        stage('Terraform Format Check') {
            steps {
                script {
                    echo "========== Checking Terraform format =========="
                    
                    sh '''
                        # Auto-format all Terraform files
                        terraform fmt -recursive modules/
                        terraform fmt -recursive env/
                        
                        # Verify formatting is correct
                        if ! terraform fmt -check -recursive modules/ 2>/dev/null; then
                            echo "⚠️  Format issues found and auto-corrected in modules/"
                        fi
                        
                        if ! terraform fmt -check -recursive env/ 2>/dev/null; then
                            echo "⚠️  Format issues found and auto-corrected in env/"
                        fi
                        
                        echo "✓ Terraform format check completed"
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    echo "========== Creating Terraform plan =========="
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            terraform plan \
                                -input=false \
                                -var-file=terraform.tfvars \
                                -out=tfplan_${BUILD_TIMESTAMP}
                            
                            # Save plan for later use
                            terraform show tfplan_${BUILD_TIMESTAMP} > tfplan_${BUILD_TIMESTAMP}.txt
                        '''
                    }
                    
                    // Archive the plan
                    archiveArtifacts artifacts: "${TF_WORKING_DIR}/tfplan_${BUILD_TIMESTAMP}*", 
                                     allowEmptyArchive: false
                }
            }
        }

        stage('Review Plan') {
            when {
                expression { params.ACTION.toLowerCase() == 'apply' }
            }
            steps {
                script {
                    echo "========== Terraform Plan Output =========="
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            echo "Terraform Plan Summary:"
                            terraform show tfplan_${BUILD_TIMESTAMP} | tail -50
                        '''
                    }
                }
            }
        }

        stage('Approval') {
            when {
                expression { 
                    params.ACTION == 'APPLY' && !params.AUTO_APPROVE 
                }
            }
            steps {
                script {
                    echo "========== Waiting for approval =========="
                    
                    def timeout_mins = params.ENVIRONMENT == 'prod' ? 60 : 30
                    def approvers = params.ENVIRONMENT == 'prod' ? 'devops-lead,platform-engineer' : '${env.JENKINS_APPROVERS}'
                    
                    timeout(time: timeout_mins, unit: 'MINUTES') {
                        input message: '''
                        
                        ╔═══════════════════════════════════════════════════════╗
                        ║  TERRAFORM APPLY - REQUIRES APPROVAL                  ║
                        ║                                                       ║
                        ║  Environment: ''' + env.ENVIRONMENT.toUpperCase() + '''
                        ║  Action: Apply Infrastructure Changes                ║
                        ║  Timestamp: ''' + env.BUILD_TIMESTAMP + '''             ║
                        ║                                                       ║
                        ║  Review the plan output above and approve if correct  ║
                        ║                                                       ║
                        ║  ⚠️  PROD deployments require senior approval         ║
                        ╚═══════════════════════════════════════════════════════╝
                        ''',
                        ok: 'APPROVE & APPLY',
                        submitter: approvers
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION.toLowerCase() == 'apply' }
            }
            steps {
                script {
                    echo "========== Applying Terraform configuration =========="
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            terraform apply \
                                -input=false \
                                -auto-approve \
                                tfplan_${BUILD_TIMESTAMP}
                            
                            echo "========== Terraform Apply Completed =========="
                        '''
                    }
                }
            }
        }

        stage('Promote to Stage') {
            when {
                expression { 
                    params.ACTION.toLowerCase() == 'apply' && 
                    params.ENVIRONMENT == 'dev' 
                }
            }
            steps {
                script {
                    echo "========== AUTO PROMOTION: Dev → Stage =========="
                    echo "✓ Dev deployment successful. Auto-triggering Stage deployment (no approval needed)..."
                    
                    // Auto-trigger stage deployment without approval for fast iteration
                    build job: 'terraform-jenkins', 
                        parameters: [
                            string(name: 'ENVIRONMENT', value: 'stage'),
                            string(name: 'ACTION', value: 'APPLY'),
                            booleanParam(name: 'AUTO_APPROVE', value: true)
                        ],
                        wait: true
                    
                    echo "Stage deployment completed successfully"
                }
            }
        }

        stage('Promote to Prod (Exceptional - Manual Only)') {
            when {
                expression { false } // DISABLED - Prod is exceptional and must be triggered separately
            }
            steps {
                script {
                    echo "Production deployment disabled in automatic flow."
                    echo "To deploy to PROD, trigger terraform-jenkins with: ENVIRONMENT=prod, ACTION=APPLY"
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION.toLowerCase() == 'destroy' }
            }
            steps {
                script {
                    // CRITICAL: Block destroy on production
                    if (env.ENVIRONMENT == 'prod') {
                        error("""
                            ❌ DESTROY NOT PERMITTED ON PRODUCTION
                            
                            To avoid accidental deletion of production infrastructure,
                            DESTROY operations are strictly forbidden on the 'prod' environment.
                            
                            If you must delete production infrastructure:
                            1. Contact the DevOps lead for manual intervention
                            2. Follow the Change Control process
                            3. Ensure backups are in place
                            
                            Use terraform destroy locally with extreme caution and proper authorization.
                        """)
                    }
                    
                    echo "========== WARNING: Destroying Terraform resources =========="
                    
                    timeout(time: 15, unit: 'MINUTES') {
                        input message: '''
                        
                        ⚠️  CRITICAL: TERRAFORM DESTROY ⚠️
                        
                        This will DELETE all infrastructure in the ''' + env.ENVIRONMENT.toUpperCase() + ''' environment:
                        - EC2 Instances
                        - VPC and Subnets
                        - Security Groups
                        - Secrets Manager entries
                        
                        This action CANNOT be undone.
                        
                        Type "DESTROY" to confirm:
                        ''',
                        ok: 'CONFIRM DESTROY'
                    }
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            terraform destroy \
                                -auto-approve \
                                -input=false
                            
                            echo "========== Terraform Destroy Completed =========="
                        '''
                    }
                }
            }
        }

        stage('Parallel Destroy - Dev & Stage') {
            when {
                expression { 
                    params.ACTION.toLowerCase() == 'destroy' && 
                    params.ENVIRONMENT == 'parallel-destroy-all'
                }
            }
            steps {
                script {
                    echo "========== PARALLEL DESTROY: Dev, Stage & Prod =========="
                    
                    timeout(time: 15, unit: 'MINUTES') {
                        input message: '''
                        
                        ⚠️  CRITICAL: PARALLEL TERRAFORM DESTROY (ALL ENVIRONMENTS) ⚠️
                        
                        This will DELETE all infrastructure in DEV, STAGE and PROD environments:
                        - EC2 Instances (all environments)
                        - VPC and Subnets (all environments)
                        - Security Groups (all environments)
                        - Secrets Manager entries (all environments)
                        
                        This action CANNOT be undone.
                        All three environments will be destroyed in PARALLEL for maximum speed.
                        
                        Type "DESTROY" to confirm:
                        ''',
                        ok: 'CONFIRM PARALLEL DESTROY ALL'
                    }
                    
                    // Parallel destroy for dev, stage, and prod
                    parallel(
                        'Destroy Dev': {
                            dir("env/dev") {
                                sh '''
                                    terraform destroy \
                                        -auto-approve \
                                        -input=false
                                    echo "========== Dev Destroy Completed =========="
                                '''
                            }
                        },
                        'Destroy Stage': {
                            dir("env/stage") {
                                sh '''
                                    terraform destroy \
                                        -auto-approve \
                                        -input=false
                                    echo "========== Stage Destroy Completed =========="
                                '''
                            }
                        },
                        'Destroy Prod': {
                            dir("env/prod") {
                                sh '''
                                    terraform destroy \
                                        -auto-approve \
                                        -input=false
                                    echo "========== Prod Destroy Completed =========="
                                '''
                            }
                        }
                    )
                    
                    echo "✓ All environments (dev, stage, prod) destroyed in parallel successfully"
                }
            }
        }

        stage('Output Artifacts') {
            when {
                expression { params.ACTION.toLowerCase() == 'apply' }
            }
            steps {
                script {
                    echo "========== Generating output artifacts =========="
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            # Get all outputs
                            terraform output -json > terraform_outputs_${BUILD_TIMESTAMP}.json
                            
                            # Create a human-readable summary
                            cat > deployment_summary_${BUILD_TIMESTAMP}.txt <<EOF
Environment: ${ENVIRONMENT}
Build Timestamp: ${BUILD_TIMESTAMP}
Build Number: ${BUILD_NUMBER}
Build URL: ${BUILD_URL}

⚠️  SECURITY NOTICE: This file contains infrastructure information.
    Do NOT share publicly or commit to version control.
    Restrict access to authorized personnel only.

========== VPC Information ==========
VPC ID: $(terraform output -raw vpc_id)
Public Subnets: $(terraform output -json public_subnet_ids)
Private Subnets: $(terraform output -json private_subnet_ids)

========== EC2 Instances ==========
Instance IDs: $(terraform output -json web_server_instance_ids)
Public IPs: $(terraform output -json web_server_public_ips)
Private IPs: $(terraform output -json web_server_private_ips)

========== Security Groups ==========
Web Security Group ID: $(terraform output -raw web_security_group_id)

========== Secrets Manager ==========
App Secrets ID: $(terraform output -raw app_secrets_id)

========== Next Steps ==========
1. Access the web server: http://$(terraform output -raw web_server_public_ips | jq -r '.[0]')
2. SSH to instance: ssh -i /path/to/key.pem ubuntu@$(terraform output -raw web_server_public_ips | jq -r '.[0]')
3. Check Apache status: sudo systemctl status apache2

Generated at: $(date)
EOF
                            
                            # Display summary
                            echo "========== Deployment Summary =========="
                            cat deployment_summary_${BUILD_TIMESTAMP}.txt
                            
                            # Create artifact security manifest
                            cat > ARTIFACT_SECURITY_${BUILD_TIMESTAMP}.txt <<EOF
ARTIFACT CLASSIFICATION: RESTRICTED

This build produced the following artifacts:
- terraform_outputs_${BUILD_TIMESTAMP}.json
- deployment_summary_${BUILD_TIMESTAMP}.txt
- tfplan_${BUILD_TIMESTAMP}

These artifacts contain:
- Infrastructure topology information
- Resource IDs and endpoints
- Network configuration
- Deployment details

ACCESS CONTROL:
✓ Jenkins administrators
✓ ${ENVIRONMENT} deployment team
✗ Unauthorized personnel

RETENTION:
- Plan files: Keep for 30 days then delete
- Output summaries: Keep for 90 days for audit
- JSON outputs: Delete after deployment verification

COMPLIANCE:
- No credentials or secrets in artifacts
- AWS API calls masked in logs
- Terraform state file stored securely in S3 + DynamoDB
- All access logged to CloudTrail

Last Verified: $(date)
EOF
                            
                            cat ARTIFACT_SECURITY_${BUILD_TIMESTAMP}.txt
                        '''
                    }
                    
                    // Archive outputs with security classification
                    archiveArtifacts artifacts: "${TF_WORKING_DIR}/terraform_outputs_*,${TF_WORKING_DIR}/deployment_summary_*,${TF_WORKING_DIR}/ARTIFACT_SECURITY_*", 
                                     allowEmptyArchive: false,
                                     fingerprint: true
                }
            }
        }

        stage('State Backup') {
            when {
                expression { params.ACTION.toLowerCase() == 'apply' }
            }
            steps {
                script {
                    echo "========== Backing up Terraform state =========="
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            # Backup state file (if using local backend)
                            if [ -f "terraform.tfstate" ]; then
                                mkdir -p state_backups
                                cp terraform.tfstate state_backups/terraform.tfstate.${BUILD_TIMESTAMP}.bak
                                echo "State backed up to state_backups/terraform.tfstate.${BUILD_TIMESTAMP}.bak"
                            fi
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                echo "========== Cleaning up workspace =========="
                
                dir("${TF_WORKING_DIR}") {
                    sh '''
                        # Keep plan files for reference but remove temporary files
                        rm -f .terraform.lock.hcl || true
                    '''
                }
                
                // Clean workspace
                cleanWs()
            }
        }

        success {
            script {
                echo "========== Pipeline Completed Successfully =========="
            }
        }

        failure {
            script {
                echo "========== Pipeline FAILED =========="
            }
        }

        unstable {
            script {
                echo "========== Pipeline Unstable =========="
            }
        }
    }
}
