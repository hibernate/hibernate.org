pipeline {
    agent none
    options {
        disableConcurrentBuilds()
        buildDiscarder logRotator(daysToKeepStr: '30', numToKeepStr: '10')
    }
    stages {
        stage('Build for PR') {
            agent {
                label 'Worker&&Containers'
            }
            when {
                beforeAgent true
                changeRequest()
            }
            steps {
                script {
                    env.GEN_ENV = 'production'
                    docker.image('quay.io/hibernate/awestruct-build-env:latest').inside('--pull always') {
                        sh "rake setup && rake clean[all] gen[${env.GEN_ENV}]"
                    }
                }
            }
        }
        stage('Build and deploy') {
            agent {
                label 'Release'
            }
            when {
                beforeAgent true
                anyOf { branch 'production'; branch 'staging' }
                not { changeRequest() }
            }
            stages {
                stage('Build') {
                    steps {
                        script {
                            docker.image('quay.io/hibernate/awestruct-build-env:latest').inside('--pull always') {
                                sh "rake setup && rake clean[all] gen[${env.BRANCH_NAME}]"
                            }
                        }
                    }
                }
                stage('Deploy') {
                    steps {
                        configFileProvider([configFile(fileId: 'release.config.ssh', targetLocation: env.HOME + '/.ssh/config'),
                                            configFile(fileId: 'release.config.ssh.knownhosts', targetLocation: env.HOME + '/.ssh/known_hosts')]) {
                            sshagent(['jenkins.in.relation.to']) {
                                sh "_scripts/publish-to-${env.BRANCH_NAME}.sh"
                            }
                        }
                    }
                }
            }
        }
    }
}
