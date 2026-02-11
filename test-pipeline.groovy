pipeline {
    agent any

    stages {
        stage('Setup') {
            steps {
                echo 'Starting test pipeline...'
                echo "Build Number: ${env.BUILD_NUMBER}"
                echo "Job Name: ${env.JOB_NAME}"
            }
        }

        stage('Build') {
            steps {
                echo 'Simulating build process...'
                sleep(time: 2, unit: 'SECONDS')
                sh '''
                    echo "Compiling application..."
                    echo "Build completed successfully"
                '''
            }
        }

        stage('Test') {
            steps {
                echo 'Running tests...'
                sleep(time: 3, unit: 'SECONDS')
                sh '''
                    echo "Running unit tests..."
                    echo "All tests passed!"
                '''
            }
        }

        stage('Package') {
            steps {
                echo 'Creating package...'
                sleep(time: 2, unit: 'SECONDS')
                sh '''
                    echo "Packaging application..."
                    echo "Package created: app-v1.0.0.tar.gz"
                '''
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying to test environment...'
                sleep(time: 2, unit: 'SECONDS')
                sh '''
                    echo "Deploying application..."
                    echo "Deployment successful!"
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully! ✓'
        }
        failure {
            echo 'Pipeline failed! ✗'
        }
        always {
            echo "Pipeline finished at: ${new Date()}"
        }
    }
}
