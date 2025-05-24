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
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${env.MASTER_PUBLIC_IP} << 'EOF'
                        set -x
                        sudo apt-get update && apt-get install -y dos2unix
                        wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-master.sh -O /tmp/setup-ansible-master.sh
                        chmod +x /tmp/setup-ansible-master.sh
                        sudo dos2unix /tmp/setup-ansible-master.sh
                        /tmp/setup-ansible-master.sh

                        wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/prometheus.sh -O /tmp/prometheus.sh
                        chmod +x /tmp/prometheus.sh
                        /tmp/prometheus.sh

                        wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/docker.sh -O /tmp/docker.sh
                        chmod +x /tmp/docker.sh
                        /tmp/docker.sh

                        wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/k8s%20master.sh -O /tmp/k8s-master.sh
                        chmod +x /tmp/k8s-master.sh
                        /tmp/k8s-master.sh
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
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${env.NODE_PUBLIC_IP} << 'EOF'
                        set -x

                        # Download and run Ansible node setup
                        sudo apt-get update && apt-get install -y dos2unix
                        wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-node.sh -O /tmp/setup-ansible-node.sh
                        chmod +x /tmp/setup-ansible-node.sh
                        sudo dos2unix /tmp/setup-ansible-node.sh
                        /tmp/setup-ansible-node.sh

                        # Download and run Prometheus setup
                        wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/prometheus.sh -O /tmp/prometheus.sh
                        chmod +x /tmp/prometheus.sh
                        /tmp/prometheus.sh

                        # Download and run K8s node setup
                        wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/k8s-node.sh -O /tmp/k8s-node.sh
                        chmod +x /tmp/k8s-node.sh
                        /tmp/k8s-node.sh
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
                ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                    echo "${inventoryContent}" | sudo tee /etc/ansible/hosts
                '
                """
            }
        }
    }
}

        stage('Configure Prometheus') {
  steps {
    script {
      def prometheusConfig = """
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: 'finance-${env.ENVIRONMENT}-master'
    static_configs:
      - targets: ['${env.MASTER_PUBLIC_IP}:9100']

  - job_name: 'finance-${env.ENVIRONMENT}-node'
    static_configs:
      - targets: ['${env.NODE_PUBLIC_IP}:9100']
"""

      writeFile file: 'prometheus.yml', text: prometheusConfig

      // Copy the prometheus.yml to remote master node and restart prometheus
      sshagent(['ssh-key-ansadmin1']) {
        sh """
          scp -o StrictHostKeyChecking=no prometheus.yml ansadmin@${env.MASTER_PUBLIC_IP}:/prometheus/prometheus.yml
          ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
            pkill prometheus || true
            nohup /prometheus/prometheus --config.file=/prometheus/prometheus.yml > /dev/null 2>&1 &
          '
        """
      }
    }
  }
}

        // ---------------- BUILD & DEPLOY ----------------
        stage('Build with Maven') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build --no-cache -t ${FULL_IMAGE} ."
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds-id', 
                    usernameVariable: 'DOCKER_USERNAME', 
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh """
                        echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
                        docker push ${FULL_IMAGE}
                    """
                }
            }
        }

        stage('Deploy Ansible Playbook') {
            steps {
                sshagent(['ssh-key-ansadmin1']) {
                    sh """
                        scp -o StrictHostKeyChecking=no -r ${env.ANSIBLE_DIR}/ ansadmin@${env.MASTER_PUBLIC_IP}:/home/ansadmin/
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                            cd /home/ansadmin/${env.ANSIBLE_DIR}
                            ansible-playbook -i /etc/ansible/hosts install.yml -e "docker_image=${FULL_IMAGE}"
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
            mail to: 'azureashwin25@gmail.com',
                 subject: "FAILED: Pipeline ${currentBuild.fullDisplayName}",
                 body: "Check build ${env.BUILD_URL} for details"
        }
        success {
            mail to: 'azureashwin25@gmail.com',
                 subject: "SUCCESS: Pipeline ${currentBuild.fullDisplayName}",
                 body: """
                 Deployment completed successfully!

                 Master Node:
                 - Public IP: ${env.MASTER_PUBLIC_IP}
                 - SSH: ssh ansadmin@${env.MASTER_PUBLIC_IP}

                 Worker Node:
                 - Private IP: ${env.NODE_PRIVATE_IP}
                 - Docker Image: ${FULL_IMAGE}
                 """
        }
    }
}
