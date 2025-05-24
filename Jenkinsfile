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
        stage('Provision Ansible Master') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'ssh-key-ansadmin1',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    script {
                        // Generate public key safely
                        def PUBLIC_KEY = sh(script: "ssh-keygen -y -f ${SSH_KEY} | head -n 1", returnStdout: true).trim()

                        // Setup ansadmin user with proper error handling
                        sh """
                            ssh -o StrictHostKeyChecking=no -i "${SSH_KEY}" ubuntu@${env.MASTER_PUBLIC_IP} << 'EOF'
                            sudo useradd -m -s /bin/bash ansadmin || true
                            echo 'ansadmin ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/ansadmin
                            sudo mkdir -p /home/ansadmin/.ssh
                            echo '${PUBLIC_KEY}' | sudo tee /home/ansadmin/.ssh/authorized_keys
                            sudo chown -R ansadmin:ansadmin /home/ansadmin/.ssh
                            sudo chmod 700 /home/ansadmin/.ssh
                            sudo chmod 600 /home/ansadmin/.ssh/authorized_keys
EOF
                        """
                    }
                }
            }
        }

        stage('Install Ansible') {
            steps {
                sshagent(['ssh-key-ansadmin1']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                            sudo apt-get install -y software-properties-common
                            sudo apt-add-repository --yes --update ppa:ansible/ansible
                            sudo apt-get install -y ansible-core ansible sshpass
                        '
                    """
                }
            }
        }

        stage('Configure Ansible Environment') {
            steps {
                sshagent(['ssh-key-ansadmin1']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                            sudo mkdir -p /etc/ansible
                            echo "[all]" | sudo tee /etc/ansible/hosts
                            echo "${env.NODE_PRIVATE_IP}" | sudo tee -a /etc/ansible/hosts
                            echo "[defaults]" | sudo tee /etc/ansible/ansible.cfg
                            echo "host_key_checking = False" | sudo tee -a /etc/ansible/ansible.cfg
                            echo "remote_user = ansadmin" | sudo tee -a /etc/ansible/ansible.cfg
                        '
                    """
                }
            }
        }

        stage('Configure SSH Access to Node') {
            steps {
                sshagent(['ssh-key-ansadmin1']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                            ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" -q
                            ssh-keyscan -H ${env.NODE_PRIVATE_IP} >> ~/.ssh/known_hosts
                            sshpass -p "ansadmin" ssh-copy-id -i ~/.ssh/id_rsa.pub ansadmin@${env.NODE_PRIVATE_IP} || true
                        '
                    """
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
