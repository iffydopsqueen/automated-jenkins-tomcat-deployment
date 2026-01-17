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
            defaultValue: '10.0.1.247',
            description: 'Tomcat host or IP'
        )
        string(
            name: 'TOMCAT_PORT',
            defaultValue: '8080',
            description: 'Tomcat HTTP port'
        )
    }

    environment {
        DEPLOY_PATH = '/opt/tomcat/webapps'
        DEPLOY_WAR = 'app/target/ROOT.war'
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
                dir('app') {
                    sh 'mvn -B clean package'
                }
            }
        }

        stage('Prepare Artifact') {
            steps {
                sh '''
                    bash -eu -o pipefail <<'EOF'
                    WAR_FILE=$(ls -1 app/target/*.war | head -n 1)
                    cp "$WAR_FILE" "${DEPLOY_WAR}"
                    ls -lh "${DEPLOY_WAR}"
                    EOF
                '''
            }
        }

        stage('Deploy') {
            when {
                branch 'master'
            }
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'tomcat-ssh',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        bash -eu -o pipefail <<'EOF'
                        mkdir -p ~/.ssh
                        ssh-keyscan -H "${TOMCAT_HOST}" >> ~/.ssh/known_hosts
                        scp -i "${SSH_KEY}" "${DEPLOY_WAR}" "${SSH_USER}@${TOMCAT_HOST}:${DEPLOY_PATH}/ROOT.war"
                        ssh -i "${SSH_KEY}" "${SSH_USER}@${TOMCAT_HOST}" "sudo systemctl restart tomcat"
                        EOF
                    '''
                }
            }
        }

        stage('Health Check') {
            when {
                branch 'master'
            }
            steps {
                sh 'curl -f "http://${TOMCAT_HOST}:${TOMCAT_PORT}/"'
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
