pipeline {

    agent any

    triggers {
        githubPush()
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    environment {
        APP_NAME      = 'django-app'
        IMAGE_TAG     = "${env.GIT_COMMIT.take(7)}"

        DEPLOY_SERVER = '185.199.53.175'
        DEPLOY_USER   = 'prabesh'
        DEPLOY_PORT   = '22'

        APP_PORT      = '8000'
        ENV_FILE      = '/home/prabesh/.django.env'
    }

    stages {

        stage('📋 Pipeline Info') {
            steps {
                echo """
🚀 DJANGO CD PIPELINE
Build   : #${env.BUILD_NUMBER}
Branch  : ${env.BRANCH_NAME}
Commit  : ${IMAGE_TAG}
Server  : ${DEPLOY_SERVER}
"""
            }
        }

        stage('🐳 Build Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh """
                        DOCKER_IMAGE=\${DOCKER_USERNAME}/${APP_NAME}

                        docker build \\
                            --platform linux/amd64 \\
                            -t \${DOCKER_IMAGE}:${IMAGE_TAG} \\
                            -t \${DOCKER_IMAGE}:latest \\
                            .

                        echo "✅ Image built"
                    """
                }
            }
        }

        stage('🔒 Security Scan') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh """
                        DOCKER_IMAGE=\${DOCKER_USERNAME}/${APP_NAME}

                        UID=\$(docker run --rm --entrypoint id \${DOCKER_IMAGE}:${IMAGE_TAG} -u)

                        if [ "\$UID" = "0" ]; then
                            echo "❌ Running as root"
                            exit 1
                        else
                            echo "✅ Non-root container"
                        fi
                    """
                }
            }
        }

        stage('📤 Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh """
                        DOCKER_IMAGE=\${DOCKER_USERNAME}/${APP_NAME}

                        echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin

                        docker push \${DOCKER_IMAGE}:${IMAGE_TAG}
                        docker push \${DOCKER_IMAGE}:latest

                        docker logout
                        echo "✅ Pushed"
                    """
                }
            }
        }
        stage('🚀 Deploy to Production') {
            steps {
                script {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-credentials',
                            usernameVariable: 'DOCKER_USERNAME',
                            passwordVariable: 'DOCKER_PASSWORD'
                        )
                    ]) {
                        sshagent(['deployment-server-ssh']) {
                            sh """
                                DOCKER_IMAGE="\${DOCKER_USERNAME}/${APP_NAME}"
                                
                                echo "=== Deploying to Production ==="
                                echo "Server: ${DEPLOY_SERVER}"
                                echo "Image : \${DOCKER_IMAGE}:${IMAGE_TAG}"
                                
                                ssh -o StrictHostKeyChecking=no \\
                                    -p ${DEPLOY_PORT} \\
                                    ${DEPLOY_USER}@${DEPLOY_SERVER} << ENDSSH

                                    echo "=== Connected to Production Server ==="
                                    
                                    # Login to DockerHub
                                    echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
                                    set -e
                                    # Pull new image
                                    docker pull \${DOCKER_IMAGE}:${IMAGE_TAG}
                                    
                                    # Stop old container
                                    docker stop ${APP_NAME} 2>/dev/null || true
                                    docker rm   ${APP_NAME} 2>/dev/null || true

                                    # Start new container with .env file
                                    docker run -d \\
                                        --name ${APP_NAME} \\
                                        --restart unless-stopped \\
                                        --network private-net \\
                                        -p ${APP_PORT}:${APP_PORT} \\
                                        --env-file ${ENV_FILE} \\
                                        \${DOCKER_IMAGE}:${IMAGE_TAG}

                                    # Ensures the new routes and config are loaded immediately
                                    
                                    # Verify
                                    sleep 5
                                    docker ps | grep ${APP_NAME}
                                    
                                    # Show logs
                                    docker logs --tail 20 ${APP_NAME}
                                    
                                    # Cleanup old images
                                    docker images | grep \${DOCKER_IMAGE} | tail -n +6 | awk '{print \\\$3}' | xargs -r docker rmi || true
                                    
                                    docker logout
                                    
                                    echo "✅ Deployment completed!"
ENDSSH
                            """
                        }
                    }
                }
            }
        }
    stage('🏥 Health Check') {
    steps {
        script {
            sh """
                echo "=== Checking Django App on http://${DEPLOY_SERVER}:${APP_PORT}/health/ ==="

                RETRIES=10
                SLEEP=5
                for i in \$(seq 1 \$RETRIES); do
                    HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://${DEPLOY_SERVER}:${APP_PORT}/health/)
                    if [ "\$HTTP_STATUS" -eq 200 ]; then
                        echo "✅ Application is healthy!"
                        echo "🌐 Live at: http://${DEPLOY_SERVER}:${APP_PORT}"
                        exit 0
                    else
                        echo "⚠️ Health check failed (status \$HTTP_STATUS). Retrying in \$SLEEP seconds..."
                        sleep \$SLEEP
                    fi
                done

                echo "❌ Application failed health check after \$RETRIES attempts."
                exit 1
            """
        }
    }
}
        stage('🧹 Cleanup') {
            steps {
                sh "docker image prune -f || true"
            }
        }
    }

    post {
        success {
            echo "🚀 Django Deployment Successful!"
        }
        failure {
            echo "❌ Deployment Failed!"
        }
    }
}