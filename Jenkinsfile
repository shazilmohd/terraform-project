pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'stage'],
            description: 'Environment to deploy to'
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
        AWS_REGION = "${params.AWS_REGION}"
        AWS_CREDENTIALS = credentials('aws-credentials')
        SECRETS_MANAGER_CRED = credentials('secrets-manager-secret-id')
        
        // Terraform Configuration
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
                        
                        # Check if env/dev directory exists
                        if [ ! -d "${TF_WORKING_DIR}" ]; then
                            echo "Error: ${TF_WORKING_DIR} directory not found"
                            exit 1
                        fi
                        
                        echo "✓ All pre-validation checks passed"
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    echo "========== Initializing Terraform =========="
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            terraform init \
                                -upgrade \
                                -input=false
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
                expression { params.ACTION == 'APPLY' }
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
                    
                    timeout(time: 30, unit: 'MINUTES') {
                        input message: '''
                        
                        ╔═══════════════════════════════════════════════════════╗
                        ║  TERRAFORM APPLY - REQUIRES APPROVAL                  ║
                        ║                                                       ║
                        ║  Environment: ''' + env.ENVIRONMENT.toUpperCase() + '''
                        ║  Action: Apply Infrastructure Changes                ║
                        ║  Timestamp: ''' + env.BUILD_TIMESTAMP + '''             ║
                        ║                                                       ║
                        ║  Review the plan output above and approve if correct  ║
                        ╚═══════════════════════════════════════════════════════╝
                        ''',
                        ok: 'APPROVE & APPLY',
                        submitter: '${env.JENKINS_APPROVERS}'
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'APPLY' }
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

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'DESTROY' }
            }
            steps {
                script {
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

        stage('Output Artifacts') {
            when {
                expression { params.ACTION == 'APPLY' }
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
                        '''
                    }
                    
                    // Archive outputs
                    archiveArtifacts artifacts: "${TF_WORKING_DIR}/terraform_outputs_*,${TF_WORKING_DIR}/deployment_summary_*", 
                                     allowEmptyArchive: false
                }
            }
        }

        stage('State Backup') {
            when {
                expression { params.ACTION == 'APPLY' }
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
