pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TERRAFORM_DIR = 'terraform'
        IMAGE_NAME = 'financedev'
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
  success {
    emailext (
      to: 'azureashwin25@gmail.com',
      subject: "Jenkins Build Success: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
      body: "Good news! Build succeeded. Details: ${env.BUILD_URL}"
    )
  }
  unstable {
    emailext (
      to: 'azureashwin25@gmail.com',
      subject: "Jenkins Build Unstable: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
      body: "Build is unstable. Check details at ${env.BUILD_URL}"
    )
  }
  failure {
    emailext (
      to: 'azureashwin25@gmail.com',
      subject: "Jenkins Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
      body: "Check Jenkins console output at ${env.BUILD_URL}"
    )
  }
}
}

