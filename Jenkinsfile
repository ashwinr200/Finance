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
stage('Install Prerequisites on Master') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            sh '''
ssh -o StrictHostKeyChecking=no -i ''' + SSH_KEY + ''' ubuntu@''' + env.MASTER_PUBLIC_IP + ''' << 'EOF'
set -xe

# Wait for apt lock
max_wait=300
waited=0
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
  echo "$(date): Waiting for apt lock..."
  sleep 5
  waited=$((waited+5))
  if [ $waited -ge $max_wait ]; then
    echo "$(date): Timeout waiting for apt lock. Killing other apt processes..."
    sudo killall apt apt-get 2>/dev/null || true
    break
  fi
done
sudo bash -c 'until ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do echo "Waiting for lock..."; sleep 5; done'
sudo apt-get update
sudo apt-get install -y dos2unix wget curl
EOF
'''
        }
    }
}

stage('Install Ansible on Master') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            sh '''
ssh -o StrictHostKeyChecking=no -i ''' + SSH_KEY + ''' ubuntu@''' + env.MASTER_PUBLIC_IP + ''' << 'EOF'
set -xe

sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-master.sh -O /tmp/setup-ansible-master.sh
sudo dos2unix /tmp/setup-ansible-master.sh
sudo chmod +x /tmp/setup-ansible-master.sh
sudo /tmp/setup-ansible-master.sh
EOF
'''
        }
    }
}

stage('Install Prometheus on Master') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            sh '''
ssh -o StrictHostKeyChecking=no -i ''' + SSH_KEY + ''' ubuntu@''' + env.MASTER_PUBLIC_IP + ''' << 'EOF'
set -xe

sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/prometheus.sh -O /tmp/prometheus.sh
sudo dos2unix /tmp/prometheus.sh
sudo chmod +x /tmp/prometheus.sh
sudo /tmp/prometheus.sh
EOF
'''
        }
    }
}

stage('Install Docker on Master') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            sh '''
ssh -o StrictHostKeyChecking=no -i ''' + SSH_KEY + ''' ubuntu@''' + env.MASTER_PUBLIC_IP + ''' << 'EOF'
set -xe

sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/docker.sh -O /tmp/docker.sh
sudo dos2unix /tmp/docker.sh
sudo chmod +x /tmp/docker.sh
sudo /tmp/docker.sh
EOF
'''
        }
    }
}

stage('Install Kubernetes Master on Master') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            sh '''
ssh -o StrictHostKeyChecking=no -i ''' + SSH_KEY + ''' ubuntu@''' + env.MASTER_PUBLIC_IP + ''' << 'EOF'
set -xe

sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/k8s%20master.sh -O /tmp/k8s-master.sh
sudo dos2unix /tmp/k8s-master.sh
sudo chmod +x /tmp/k8s-master.sh
sudo /tmp/k8s-master.sh
EOF
'''
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
                             echo -e '[defaults]\\nhost_key_checking = False\\nroles_path = ./ansible/roles' | sudo tee /etc/ansible/ansible.cfg
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

        

stage('Install Prerequisites on Node') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            sh '''
ssh -o StrictHostKeyChecking=no -i ''' + SSH_KEY + ''' ubuntu@''' + env.NODE_PUBLIC_IP + ''' << 'EOF'
set -xe

# Wait for apt lock
max_wait=300
waited=0
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
  echo "\$(date): Waiting for apt lock..."
  sleep 5
  waited=\$((waited+5))
  if [ \$waited -ge \$max_wait ]; then
    echo "\$(date): Timeout waiting for apt lock. Killing other apt processes..."
    sudo killall apt apt-get 2>/dev/null || true
    break
  fi
done

sudo bash -c 'until ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do echo "Waiting for lock..."; sleep 5; done'

sudo apt-get update
sudo apt-get install -y dos2unix wget curl
EOF
'''
        }
    }
}


stage('Install Ansible on Node') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            sh '''
ssh -o StrictHostKeyChecking=no -i ''' + SSH_KEY + ''' ubuntu@''' + env.NODE_PUBLIC_IP + ''' << 'EOF'
set -xe

sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-node.sh -O /tmp/setup-ansible-node.sh
sudo dos2unix /tmp/setup-ansible-node.sh
sudo chmod +x /tmp/setup-ansible-node.sh
sudo /tmp/setup-ansible-node.sh
EOF
'''
        }
    }
}

stage('Install Prometheus on Node') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            sh '''
ssh -o StrictHostKeyChecking=no -i ''' + SSH_KEY + ''' ubuntu@''' + env.NODE_PUBLIC_IP + ''' << 'EOF'
set -xe

sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/prometheus.sh -O /tmp/prometheus.sh
sudo dos2unix /tmp/prometheus.sh
sudo chmod +x /tmp/prometheus.sh
sudo /tmp/prometheus.sh
EOF
'''
        }
    }
}

stage('Install Kubernetes Node') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            sh '''
ssh -o StrictHostKeyChecking=no -i ''' + SSH_KEY + ''' ubuntu@''' + env.NODE_PUBLIC_IP + ''' << 'EOF'
set -xe

sudo wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/k8s-node.sh -O /tmp/k8s-node.sh
sudo dos2unix /tmp/k8s-node.sh
sudo chmod +x /tmp/k8s-node.sh
sudo /tmp/k8s-node.sh
EOF
'''
        }
    }
}
stage('Provision ansadmin on Node') {
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin1', keyFileVariable: 'SSH_KEY')]) {
            script {
                def publicKey = sh(script: "ssh-keygen -y -f ${SSH_KEY}", returnStdout: true).trim()
                
                sh(script: """ssh -o StrictHostKeyChecking=no -i "${SSH_KEY}" ubuntu@${env.NODE_PUBLIC_IP} bash -c '
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
                def inventoryContent = """[k8s-master]
${env.MASTER_PRIVATE_IP}

[k8s-node]
${env.NODE_PRIVATE_IP}

[all:vars]
ansible_user=ansadmin

[local]
localhost ansible_connection=local ansible_user=ansadmin
"""

                // Properly escape the content for SSH command
                def escapedContent = inventoryContent
                    .replace('\\', '\\\\')
                    .replace('"', '\\"')
                    .replace('$', '\\$')
                    .replace('`', '\\`')

                sh """
                    ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} \
                        'echo "${escapedContent}" | sudo tee /etc/ansible/hosts > /dev/null'
                """
            }
        }
    }
    }
        stage('Build with Maven') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${FULL_IMAGE} ."
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds-id', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    sh """
                        echo "$PASSWORD" | docker login -u "$USERNAME" --password-stdin
                        docker push ${FULL_IMAGE}
                    """
                }
            }
        }


        stage('Deploy to Kubernetes via Ansible') {
            steps {
                ansiblePlaybook credentialsId: 'ssh-key-ansadm', 
                                installation: 'ansible2', 
                                inventory: '/etc/ansible/hosts', 
                                playbook: 'ansible-deploy.yml', 
                                vaultTmpPath: '',
                     extraVars: [
                            build_tag: "${BRANCH_TAG}",
                            image_name: "${FULL_IMAGE}"
                        ]
               
            }  }
    }
    

  
    post {
        always {
            cleanWs()
        }
    }
}
