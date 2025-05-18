pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
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
                    if (env.BRANCH_NAME == 'prod') {
                        tfVarsFile = 'prod.tfvars'
                    } else if (env.BRANCH_NAME == 'stage') {
                        tfVarsFile = 'stage.tfvars'
                    }

                    dir(env.TERRAFORM_DIR) {
                        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                            sh "terraform apply -auto-approve -var-file=${tfVarsFile}"

                            env.MASTER_PRIVATE_IP = sh(
                                script: "terraform output -raw master_private_ip", 
                                returnStdout: true
                            ).trim()
                            env.MASTER_PUBLIC_IP = sh(
                                script: "terraform output -raw master_public_ip", 
                                returnStdout: true
                            ).trim()
                            env.NODE_PRIVATE_IP = sh(
                                script: "terraform output -raw node_private_ip", 
                                returnStdout: true
                            ).trim()
                            env.NODE_PUBLIC_IP = sh(
                                script: "terraform output -raw node_public_ip", 
                                returnStdout: true
                            ).trim()

                            echo """
                            Infrastructure deployed successfully!
                            Master Public IP: ${env.MASTER_PUBLIC_IP}
                            Node Public IP: ${env.NODE_PUBLIC_IP}
                            """
                        }
                    }
                }
            }
        }
  stage('Verify SSH Access') {
    steps {
        sshagent(credentials: ['ssh-key-ansadmin']) {
            // Test basic SSH connection
            sh 'ssh -o StrictHostKeyChecking=no -v ansadmin@${env.MASTER_PUBLIC_IP} whoami'
        }
    }
}

      stage('Install and Configure Ansible') {
    steps {
        sshagent(credentials: ['ssh-key-ansadmin']) {
            sh """
                # Install Ansible on master
                ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                    sudo apt-get update -qq &&
                    sudo apt-get install -y software-properties-common &&
                    sudo apt-add-repository --yes --update ppa:ansible/ansible &&
                    sudo apt-get install -y ansible
                '
                
                # Create Ansible directory structure
                ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                    sudo mkdir -p /etc/ansible &&
                    echo -e "[ansiblegroup]\\n${env.NODE_PRIVATE_IP}" | sudo tee /etc/ansible/hosts > /dev/null &&
                    echo -e "[defaults]\\nhost_key_checking = False" | sudo tee /etc/ansible/ansible.cfg > /dev/null
                '
                
                # Copy SSH key from master to worker node
                ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} "
                    ssh-keygen -t rsa -f /home/ansadmin/.ssh/id_rsa -N '' &&
                    ssh-keyscan ${env.NODE_PRIVATE_IP} >> /home/ansadmin/.ssh/known_hosts &&
                    ssh-copy-id -i /home/ansadmin/.ssh/id_rsa.pub ansadmin@${env.NODE_PRIVATE_IP}
                "
            """
        }
    }
}
      
        stage('Copy Ansible Playbook') {
            steps {
                sshagent(credentials: ['ssh-key-ansadmin']) {
                    sh """
                        scp -o StrictHostKeyChecking=no -r ${env.ANSIBLE_DIR}/ ansadmin@${env.MASTER_PUBLIC_IP}:/home/ansadmin/
                    """
                }
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                sshagent(credentials: ['ssh-key-ansadmin']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                            cd /home/ansadmin/${env.ANSIBLE_DIR} &&
                            ansible-playbook install.yml -i /etc/ansible/hosts
                        '
                    """
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline completed - cleaning up workspace'
            cleanWs()
        }
        failure {
            mail to: 'devops-team@example.com',
                 subject: "FAILED: Pipeline ${currentBuild.fullDisplayName}",
                 body: "Check build ${env.BUILD_URL} for details"
        }
        success {
            mail to: 'devops-team@example.com',
                 subject: "SUCCESS: Pipeline ${currentBuild.fullDisplayName}",
                 body: "Deployment completed successfully!\n\nMaster IP: ${env.MASTER_PUBLIC_IP}\nNode IP: ${env.NODE_PUBLIC_IP}"
        }
    }
}
