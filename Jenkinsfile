pipeline {
    agent { label "jenkins_slave" }
    parameters {
        choice(choices: [ '4.3.1', '4.2.9', '4.2.9.4', '4.2.8', '4.2.7', '4.2.7', '4.2.6', '4.1.8.4', '4.1.7.3', '3.9.6'], description: 'Specify DSS Version to Build', name: 'DSS_VERSION')
    }
    environment {
        docker_image = "hmpps/dss"
        aws_region = 'eu-west-2'
        ecr_repo = ''
        image_tag_version = '3.1' // temp for testing
    }

    stages {
        stage ('Notify build started') {
            steps {
                slackSend(message: "Build Started - ${env.JOB_NAME} ${env.BUILD_NUMBER} (<${env.BUILD_URL.replace('http://', 'https://').replace(':8080', '')}|Open>)")
            }
        }
        stage('Get ECR Login') {
            steps {
                sh '''
                    #!/bin/bash +x
                    make ecr-login
                '''
                // Stash the ecr repo to save a repeat aws api call
                stash includes: 'ecr.repo', name: 'ecr.repo'
            }
        }
        stage('Build Docker image') {
           steps {
                unstash 'ecr.repo'
                sh '''
                    #!/bin/bash +x
                    make build dss_version=${DSS_VERSION} image_tag_version=${IMAGE_TAG_VERSION}
                '''
            }
        }
        stage('Image Tests') {
            steps {
                // Run dgoss tests
                sh '''
                    #!/bin/bash +x
                    make test
                '''
            }
        }
        stage('Push image') {
            steps{
                unstash 'ecr.repo'
                sh '''
                    #!/bin/bash +x
                    make push dss_version=${DSS_VERSION} image_tag_version=${IMAGE_TAG_VERSION}
                '''
                
            }            
        }
        stage ('Remove untagged ECR images') {
            steps{
                unstash 'ecr.repo'
                sh '''
                    #!/bin/bash +x
                    make clean-remote
                '''
            }
        }
        stage('Remove Unused docker image') {
            steps{
                unstash 'ecr.repo'
                sh '''
                    #!/bin/bash +x
                    make clean-local image_tag_version=${IMAGE_TAG_VERSION}
                '''
            }
        }
    }
    post {
        success {
            slackSend(message: "Build successful -${env.JOB_NAME} ${env.BUILD_NUMBER} (<${env.BUILD_URL.replace('http://', 'https://').replace(':8080', '')}|Open>)", color: 'good')
        }
        failure {
            slackSend(message: "Build failed - ${env.JOB_NAME} ${env.BUILD_NUMBER} (<${env.BUILD_URL.replace('http://', 'https://').replace(':8080', '')}|Open>)", color: 'danger')
        }
    }
}
