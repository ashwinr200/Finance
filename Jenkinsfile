pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        IMAGE_NAME = 'financestage'
        DOCKER_USER = 'ashwinr2001'
        BRANCH_TAG = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}".replaceAll('/', '-')
        FULL_IMAGE = "${DOCKER_USER}/${IMAGE_NAME}:${BRANCH_TAG}"
        ENVIRONMENT = "${env.BRANCH_NAME == 'prod' ? 'prod' : 'stage'}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Clone Repo') {
            steps {
                git branch: 'stage', url: 'https://github.com/ashwinr200/Finance.git'
            }
        }

        // ---------------- INFRA ----------------
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
                    def tfVarsFile = (env.BRANCH_NAME == 'prod') ? 'prod.tfvars' : 'stage.tfvars'
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

        // ---------------- ANSIBLE SETUP ----------------
        stage('Install Tools on Master (Docker, Ansible, K8s, Prometheus)') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ssh-key-ansadmin1',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${env.MASTER_PUBLIC_IP} << EOF
set -xe

                        max_wait=300
                        waited=0
                        while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
                          echo "Waiting for other apt processes to finish..."
                          sleep 5
                          waited=$((waited+5))
                          if [ $waited -ge $max_wait ]; then
                            echo "Timeout waiting for apt lock, exiting."
                            exit 1
                          fi
                        done

                        sudo apt-get update && sudo apt-get install -y dos2unix wget curl

                        # Download and run ansible master setup script
                        sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-master.sh -O /tmp/setup-ansible-master.sh
                        sudo dos2unix /tmp/setup-ansible-master.sh
                        sudo chmod +x /tmp/setup-ansible-master.sh
                        sudo /tmp/setup-ansible-master.sh

                        # Download and run Prometheus install script
                        sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/prometheus.sh -O /tmp/prometheus.sh
                        sudo dos2unix /tmp/prometheus.sh
                        sudo chmod +x /tmp/prometheus.sh
                        sudo /tmp/prometheus.sh

                        # Download and run Docker install script
                        sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/docker.sh -O /tmp/docker.sh
                        sudo dos2unix /tmp/docker.sh
                        sudo chmod +x /tmp/docker.sh
                        sudo /tmp/docker.sh

                        # Download and run Kubernetes master install script
                        sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/k8s%20master.sh -O /tmp/k8s-master.sh
                        sudo dos2unix /tmp/k8s-master.sh
                        sudo chmod +x /tmp/k8s-master.sh
                        sudo /tmp/k8s-master.sh
                        EOF
                    """
                }
            }
        }

        stage('Install Tools on Node (Ansible, Prometheus, K8s)') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ssh-key-ansadmin1',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${env.NODE_PUBLIC_IP} << EOF
                        set -xe
                        max_wait=300
                        waited=0
                        while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
                          echo "Waiting for other apt processes to finish..."
                          sleep 5
                          waited=$((waited+5))
                          if [ $waited -ge $max_wait ]; then
                            echo "Timeout waiting for apt lock, exiting."
                            exit 1
                          fi
                        done

                        sudo apt-get update && sudo apt-get install -y dos2unix wget curl

                        # Download and run Ansible node setup script
                        sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-node.sh -O /tmp/setup-ansible-node.sh
                        sudo dos2unix /tmp/setup-ansible-node.sh
                        sudo chmod +x /tmp/setup-ansible-node.sh
                        sudo /tmp/setup-ansible-node.sh

                        # Download and run Prometheus setup script
                        sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/prometheus.sh -O /tmp/prometheus.sh
                        sudo dos2unix /tmp/prometheus.sh
                        sudo chmod +x /tmp/prometheus.sh
                        sudo /tmp/prometheus.sh

                        # Download and run Kubernetes node setup script
                        sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/k8s-node.sh -O /tmp/k8s-node.sh
                        sudo dos2unix /tmp/k8s-node.sh
                        sudo chmod +x /tmp/k8s-node.sh
                        sudo /tmp/k8s-node.sh
                        EOF
                    """
                }
            }
        }

        stage('Provision Ansible Master') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
                    script {
                        def publicKey = sh(script: "ssh-keygen -y -f ${SSH_KEY}", returnStdout: true).trim()
                        
                        sh(script: """ssh -o StrictHostKeyChecking=no -i "${SSH_KEY}" ubuntu@${env.MASTER_PUBLIC_IP} bash -c '
                            sudo useradd -m -s /bin/bash ansadmin || true
                            echo "ansadmin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansadmin
                            sudo mkdir -p /home/ansadmin/.ssh
                            echo "${publicKey}" | sudo tee /home/ansadmin/.ssh/authorized_keys
                            sudo chown -R ansadmin:ansadmin /home/ansadmin/.ssh
                            sudo chmod 700 /home/ansadmin/.ssh
                            sudo chmod 600 /home/ansadmin/.ssh/authorized_keys
                        '""")
                    }
                }
            }
        }

        stage('Configure Ansible Environment') {
            steps {
                sshagent(credentials: ['ssh-key-ansadmin1']) {
                    sh """
                        # First create the Ansible directory structure
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                            sudo mkdir -p /etc/ansible &&
                            sudo chown ansadmin:ansadmin /etc/ansible
                        '
                    
                        # Now configure the files
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} "
                            echo -e '[all]\\n${env.NODE_PRIVATE_IP}' | sudo tee /etc/ansible/hosts
                            echo -e '[defaults]\\nhost_key_checking = False' | sudo tee /etc/ansible/ansible.cfg
                            sudo chmod 644 /etc/ansible/*
                        "
                        
                        # Verify the configuration
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                            ls -la /etc/ansible/
                            cat /etc/ansible/hosts
                            cat /etc/ansible/ansible.cfg
                        '
                    """
                }
            }
        }

        stage('Join Node to Kubernetes Master') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ssh-key-ansadmin1',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    script {
                        // Fetch join command from master
                        def joinCommand = sh(
                            script: """
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ansadmin@${env.MASTER_PUBLIC_IP} '
                                sudo kubeadm token create --print-join-command
                            '
                            """,
                            returnStdout: true
                        ).trim()

                        // Append CRI socket path
                        def fullJoinCommand = "${joinCommand} --cri-socket unix:///var/run/cri-dockerd.sock"
                        echo "Executing on node: ${fullJoinCommand}"

                        // Run join command on the node
                        sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ansadmin@${env.NODE_PRIVATE_IP} '
                            sudo ${fullJoinCommand}
                        '
                        """
                    }
                }
            }
        }

        stage('Write Ansible Inventory') {
            steps {
                sshagent(['ssh-key-ansadmin1']) {
                    script {
                        def inventoryContent = """
[k8s-master]
${env.MASTER_PRIVATE_IP}

[k8s-node]
${env.NODE_PRIVATE_IP}

[all:vars]
ansible_user=ansadmin

[local]
localhost ansible_connection=local ansible_user=ansadmin
"""
                        sh """
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PRIVATE_IP} 'echo """ + 
                        inventoryContent.replaceAll('"', '\\"') + """ > ~/inventory.ini'
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
