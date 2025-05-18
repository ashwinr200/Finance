pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        IMAGE_NAME = 'finance-dev'
      DOCKER_REGISTRY = 'ashwinr2001/financedev18may2025capstone:v1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Clone Repo') {
            steps {
                git branch: 'dev', url: 'https://github.com/ashwinr200/Finance.git'
            }
        }

        stage('Build with Maven') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${DOCKER_REGISTRY} ."
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds-id', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    sh """
                        echo "$PASSWORD" | docker login -u "$USERNAME" --password-stdin
                        docker push ${DOCKER_REGISTRY}
                    """
                }
            }
        }
         stage('Run Container') {
            steps {
                sh 'docker run -d -p 2021:8080 $DOCKER_REGISTRY'
            }
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

        stage('Provision Ansible Master') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-ansadmin', keyFileVariable: 'SSH_KEY')]) {
                    script {
                        def PUBLIC_KEY = sh(script: "ssh-keygen -y -f ${env.SSH_KEY}", returnStdout: true).trim()
                        
                        sh """
                            # Configure ansadmin user on master
                            ssh -o StrictHostKeyChecking=no -i ${env.SSH_KEY} ubuntu@${env.MASTER_PUBLIC_IP} '
                                sudo useradd -m -s /bin/bash ansadmin || true
                                echo "ansadmin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansadmin
                                sudo mkdir -p /home/ansadmin/.ssh
                                echo "${PUBLIC_KEY}" | sudo tee /home/ansadmin/.ssh/authorized_keys
                                sudo chown -R ansadmin:ansadmin /home/ansadmin/.ssh
                                sudo chmod 700 /home/ansadmin/.ssh
                                sudo chmod 600 /home/ansadmin/.ssh/authorized_keys
                            '
                        """
                    }
                }
            }
        }

stage('Install Ansible') {
    steps {
        sshagent(credentials: ['ssh-key-ansadmin']) {
            sh """
                ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                    # Fix any broken packages first
                    sudo apt-get update -qq
                    sudo apt-get install -y --fix-broken
                    sudo apt-get autoremove -y
                    
                    # Install prerequisites
                    sudo apt-get install -y software-properties-common
                    sudo apt-add-repository --yes --update ppa:ansible/ansible
                    
                    # Install Ansible with proper dependencies
                    sudo apt-get update -qq
                    sudo apt-get install -y ansible-core ansible sshpass
                    
                    # Verify installation
                    ansible --version
                '
            """
        }
    }
}

        stage('Configure Ansible Environment') {
    steps {
        sshagent(credentials: ['ssh-key-ansadmin']) {
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

 stage('Configure SSH Access') {
    steps {
        sshagent(credentials: ['ssh-key-ansadmin']) {
            sh """
                # 1. Generate SSH key on master (from Jenkins)
                ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                    [ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ""
                    chmod 600 ~/.ssh/id_rsa
                '

                # 2. Add worker's private IP to known_hosts and copy key
                ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} "
                    ssh-keyscan ${env.NODE_PRIVATE_IP} >> ~/.ssh/known_hosts
                    sshpass -p 'ansadmin' ssh-copy-id -f -i ~/.ssh/id_rsa.pub ansadmin@${env.NODE_PRIVATE_IP}
                    ssh -o StrictHostKeyChecking=no ansadmin@${env.NODE_PRIVATE_IP} 'echo SSH connection successful!'
                "
            """
        }
    }
}


        stage('Deploy Ansible Playbook') {
            steps {
                sshagent(credentials: ['ssh-key-ansadmin']) {
                    sh """
                        scp -o StrictHostKeyChecking=no -r ${env.ANSIBLE_DIR}/ ansadmin@${env.MASTER_PUBLIC_IP}:/home/ansadmin/
                        ssh -o StrictHostKeyChecking=no ansadmin@${env.MASTER_PUBLIC_IP} '
                            cd /home/ansadmin/${env.ANSIBLE_DIR}
                            ansible-playbook -i /etc/ansible/hosts install.yml
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
                 body: """
                 Deployment completed successfully!
                 
                 Master Node:
                 - Public IP: ${env.MASTER_PUBLIC_IP}
                 - Private IP: ${env.MASTER_PRIVATE_IP}
                 
                 Worker Node:
                 - Public IP: ${env.NODE_PUBLIC_IP}
                 - Private IP: ${env.NODE_PRIVATE_IP}
                 """
        }
    }
}
