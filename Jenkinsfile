pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TERRAFORM_DIR = 'terraform'
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
                    if (env.BRANCH_NAME == 'prod') tfVarsFile = 'prod.tfvars'
                    else if (env.BRANCH_NAME == 'stage') tfVarsFile = 'stage.tfvars'
                    else error "Branch ${env.BRANCH_NAME} not supported"

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
                    if (env.BRANCH_NAME == 'prod') tfVarsFile = 'prod.tfvars'
                    else if (env.BRANCH_NAME == 'stage') tfVarsFile = 'stage.tfvars'

                    dir(env.TERRAFORM_DIR) {
                        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                            sh "terraform apply -auto-approve -var-file=${tfVarsFile}"

                            env.MASTER_PRIVATE_IP = sh(script: "terraform output -raw master_private_ip", returnStdout: true).trim()
                            env.MASTER_PUBLIC_IP  = sh(script: "terraform output -raw master_public_ip", returnStdout: true).trim()
                            env.NODE_PRIVATE_IP   = sh(script: "terraform output -raw node_private_ip", returnStdout: true).trim()
                            env.NODE_PUBLIC_IP    = sh(script: "terraform output -raw node_public_ip", returnStdout: true).trim()

                            echo "Master Public IP: ${env.MASTER_PUBLIC_IP}"
                        }
                    }
                }
            }
        }

        stage('Install Ansible') {
            steps {
                sshagent(credentials: ['ssh-key-ansadmin']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                            curl -O https://raw.githubusercontent.com/ashwinr200/Finance/refs/heads/stage/ansible/install_ansible.sh &&
                            chmod +x install_ansible.sh &&
                            sudo ./install_ansible.sh
                        '
                    """
                }
            }
        }

        stage('Configure Ansible Hosts File') {
            steps {
                script {
                    sshagent(credentials: ['ssh-key-ansadmin']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} \\
                            "echo '[ansiblegroup]' | sudo tee /etc/ansible/hosts > /dev/null && \\
                             echo '${env.NODE_PRIVATE_IP}' | sudo tee -a /etc/ansible/hosts > /dev/null"
                        """
                    }
                }
            }
        }

        stage('Copy Ansible Files & Run Playbook') {
            steps {
                sshagent(credentials: ['ssh-key-ansadmin']) {
                    sh """
                        scp -o StrictHostKeyChecking=no -r ansible/ ansadmin@${env.MASTER_PUBLIC_IP}:/home/ansadmin/
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} \\
                        'cd /home/ansadmin/ansible && ansible-playbook install.yml -i /etc/ansible/hosts'
                    """
                }
            }
        }
    }

    post {
        failure {
            mail to: 'you@example.com',
                 subject: "Build failed in branch ${env.BRANCH_NAME}",
                 body: "Terraform apply or Ansible step failed. Please check the Jenkins job."
        }
    }
}
