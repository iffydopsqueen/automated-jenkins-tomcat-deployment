// CI/CD Pipeline for Java Application Deployment to Tomcat

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    triggers {
        githubPush()
    }

    parameters {
        string(
            name: 'TOMCAT_HOST',
            defaultValue: '10.0.1.48', 
            description: 'Tomcat host or IP'
        )
        string(
            name: 'TOMCAT_PORT',
            defaultValue: '8080',
            description: 'Tomcat HTTP port'
        )
    }

    environment {
        APP_NAME = 'myapp'
        APP_DIR = 'app'
        DEPLOY_PATH = '/opt/tomcat/webapps'
        DEPLOY_WAR = "${DEPLOY_PATH}/${APP_NAME}.war"
    }

    stages {
        stage('Validate') {
            steps {
                script {
                    if (!params.TOMCAT_HOST?.trim()) {
                        error('Set TOMCAT_HOST in the job parameters before running the pipeline.')
                    }
                }
            }
        }

        stage('Build') {
            steps {
                dir(env.APP_DIR) {
                    sh 'mvn clean package'
                }
            }
        }

        stage('Prepare Artifact') {
            steps {
                sh '''
                    bash -eu -o pipefail -c '
                      WAR_FILE=$(ls -1 app/target/*.war | head -n 1)
                      if [ "$(id -u)" -eq 0 ]; then
                        mkdir -p "${DEPLOY_PATH}"
                        chown tomcat:tomcat "${DEPLOY_PATH}"
                        chmod 2775 "${DEPLOY_PATH}"
                        cp "$WAR_FILE" "${DEPLOY_WAR}"
                        chown tomcat:tomcat "${DEPLOY_WAR}"
                        chmod 0644 "${DEPLOY_WAR}"
                      else
                        sudo mkdir -p "${DEPLOY_PATH}"
                        sudo chown tomcat:tomcat "${DEPLOY_PATH}"
                        sudo chmod 2775 "${DEPLOY_PATH}"
                        sudo cp "$WAR_FILE" "${DEPLOY_WAR}"
                        sudo chown tomcat:tomcat "${DEPLOY_WAR}"
                        sudo chmod 0644 "${DEPLOY_WAR}"
                      fi
                      ls -lh "${DEPLOY_WAR}"
                    '
                '''
            }
        }

        stage('Deploy') {
            when {
                expression { env.GIT_BRANCH == 'origin/master' }
            }
            steps {
                sh '''
                    bash -eu -o pipefail -c '
                      if [ "$(id -u)" -eq 0 ]; then
                        systemctl restart tomcat
                        systemctl status tomcat --no-pager
                      else
                        sudo systemctl restart tomcat
                        sudo systemctl status tomcat --no-pager
                      fi
                    '
                '''
            }
        }

        stage('Health Check') {
            when {
                anyOf {
                    branch 'master'
                    branch 'main'
                }
            }
            steps {
                sh '''
                    bash -eu -o pipefail -c '
                      echo "Waiting for Tomcat to start..."
                      sleep 15
                      for i in $(seq 1 10); do
                        echo "Checking Tomcat at http://${TOMCAT_HOST}:${TOMCAT_PORT}/myapp/ (attempt ${i})"
                        if curl -f "http://${TOMCAT_HOST}:${TOMCAT_PORT}/myapp/"; then
                          exit 0
                        fi
                        if [ "$i" -lt 10 ]; then
                          echo "Tomcat not yet available, retrying in 10 seconds..."
                          sleep 10
                        fi
                      done
                      echo "Tomcat health check failed after 10 attempts."
                      exit 1
                    '
                '''
            }
        }
    }

    post {
        success {
            echo 'Deployment completed.'
        }
        failure {
            echo 'Build or deployment failed.'
        }
    }
}
