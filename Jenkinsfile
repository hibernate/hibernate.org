pipeline {
    agent {
        label 'Worker&&Containers'
    }
    options {
        disableConcurrentBuilds()
    }
    stages {
        stage('Build') {
            steps {
                script {
                    if ( env.BRANCH_NAME == 'production' ) {
                        env.GEN_ENV = 'production'
                    }
                    else {
                        env.GEN_ENV = 'staging'
                    }
                    // Build the website inside a container
                    docker.image('quay.io/hibernate/awestruct-build-env:latest').inside('--pull always') {
                        sh "rake setup && rake clean[all] gen[${env.GEN_ENV}]"
                    }
                }
            }
        }
        stage('Deploy to staging') {
            when {
                beforeAgent true
                branch 'staging'
                not { changeRequest() }
            }
            steps {
                sshagent(['jenkins.in.relation.to']) {
                    sh '_scripts/publish-to-staging.sh'
                }
            }
        }
        stage('Deploy to production') {
            when {
                beforeAgent true
                branch 'production'
                not { changeRequest() }
            }
            steps {
                configFileProvider([configFile(fileId: 'release.config.ssh', targetLocation: env.HOME + '/.ssh/config')]) {
                    // Need an SSH agent to have the key available when pushing to GitHub.
                    sshagent(['ed25519.Hibernate-CI.github.com']) {
                        sh '_scripts/publish-to-production-github-pages.sh'
                    }
                    sshagent(['jenkins.in.relation.to']) {
                        sh '_scripts/publish-to-production-self-hosted.sh'
                    }
                }
            }
        }
    }
    post {
        always {
            zulipNotification smartNotification: 'disabled', stream: 'hibernate-infra', topic: 'activity'
        }
    }
}
