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
        withCredentials([usernamePassword(
            credentialsId: 'dockerhub-credentials',
            usernameVariable: 'DOCKER_USERNAME',
            passwordVariable: 'DOCKER_PASSWORD'
        )]) {
            sshagent(['deployment-server-ssh']) {
                sh '''
                    DOCKER_IMAGE=${DOCKER_USERNAME}/${APP_NAME}

                    ssh -o StrictHostKeyChecking=no -p ${DEPLOY_PORT} ${DEPLOY_USER}@${DEPLOY_SERVER} << EOF
                        set -e

                        echo "✅ Connected"

                        # Create network if not exists
                        docker network inspect private-net >/dev/null 2>&1 || docker network create private-net

                        # Docker login
                        echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin

                        # Pull latest image
                        docker pull ${DOCKER_IMAGE}:${IMAGE_TAG}

                        # Stop & remove old container safely
                        docker rm -f ${APP_NAME} || true

                        # Run new container
                        docker run -d \\
                            --name ${APP_NAME} \\
                            --restart unless-stopped \\
                            --network private-net \\
                            -p ${APP_PORT}:${APP_PORT} \\
                            ${DOCKER_IMAGE}:${IMAGE_TAG}

                        echo "⏳ Waiting for container..."
                        sleep 5

                        # Verify container
                        docker ps | grep ${APP_NAME}

                        # Show logs
                        docker logs --tail 20 ${APP_NAME}

                        docker logout
                        echo "✅ Deployment done"
                    EOF
                '''
            }
        }
    }
}

        stage('🏥 Health Check') {
            steps {
                sh """
                    echo "=== Health Check ==="

                    apk add --no-cache curl || true

                    sleep 20

                    for i in \$(seq 1 10); do
                        if curl -f http://${DEPLOY_SERVER}:${APP_PORT}/; then
                            echo "✅ Django app is healthy"
                            exit 0
                        else
                            echo "⏳ Waiting..."
                            sleep 5
                        fi
                    done

                    echo "❌ Health check failed"
                    exit 1
                """
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