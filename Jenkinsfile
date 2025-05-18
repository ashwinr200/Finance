pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TERRAFORM_DIR = 'terraform'  // change if needed
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                dir(env.TERRAFORM_DIR) {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                        sh 'terraform init'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    def tfVarsFile = ''
                    if (env.BRANCH_NAME == 'prod') {
                        tfVarsFile = 'prod.tfvars'
                    } else if (env.BRANCH_NAME == 'stage') {
                        tfVarsFile = 'stage.tfvars'
                    } else {
                        error "Branch ${env.BRANCH_NAME} not supported"
                    }
                    dir(env.TERRAFORM_DIR) {
                        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                            sh "terraform plan -var-file=${tfVarsFile}"
                        }
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    def tfVarsFile = ''
                    def envName = ''
                    if (env.BRANCH_NAME == 'prod') {
                        tfVarsFile = 'prod.tfvars'
                        envName = 'prod'
                    } else if (env.BRANCH_NAME == 'stage') {
                        tfVarsFile = 'stage.tfvars'
                        envName = 'stage'
                    }
                    dir(env.TERRAFORM_DIR) {
                        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                            sh "terraform apply -auto-approve -var-file=${tfVarsFile}"

                            // Capture outputs
                           def masterPrivateIp = sh (
    script: "terraform output -raw master_private_ip",
    returnStdout: true
).trim()

                         def masterPublicIp = sh (
    script: "terraform output -raw master_public_ip",
    returnStdout: true
).trim()

def nodePrivateIp = sh (
    script: "terraform output -raw node_private_ip",
    returnStdout: true
).trim()

def nodePublicIp = sh (
    script: "terraform output -raw node_public_ip",
    returnStdout: true
).trim()


                            echo "Master Private IP: ${masterPrivateIp}"
                            echo "Master Public IP: ${masterPublicIp}"
                            echo "Node Private IP: ${nodePrivateIp}"
                            echo "Node Public IP: ${nodePublicIp}"

                            // Save to environment variables if needed later
                            env.MASTER_PRIVATE_IP = masterPrivateIp
                            env.MASTER_PUBLIC_IP = masterPublicIp
                            env.NODE_PRIVATE_IP = nodePrivateIp
                            env.NODE_PUBLIC_IP = nodePublicIp
                        }
                    }
                }
            }
        }
    }

    post {
        failure {
            mail to: 'you@example.com',
                 subject: "Build failed in branch ${env.BRANCH_NAME}",
                 body: "Terraform apply failed. Please check the Jenkins job."
        }
    }
}
