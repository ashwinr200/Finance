pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TERRAFORM_DIR = 'terraform'
        IMAGE_NAME = 'finance-dev'
        DOCKER_REGISTRY = 'ashwinr2001/financedev19may2025capstone:v1'
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
                sh "docker build -t ${DOCKER_REGISTRY} ."
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

       stage('Deploy to Kubernetes via Ansible') {
    steps {
      
            sh 'ansible-playbook -i /etc/ansible/hosts ansible-deploy.yml -b -u ansadmin'

       

        
    }
}


    }
}
