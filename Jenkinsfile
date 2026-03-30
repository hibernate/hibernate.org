pipeline {
    agent none
    options {
        disableConcurrentBuilds()
        buildDiscarder logRotator(daysToKeepStr: '30', numToKeepStr: '10')
    }
    triggers {
        // Run every Saturday at midnight to update members.json
        cron('0 0 * * 6')
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
                stage('Update members.json') {
                    steps {
                        script {
                            // First, update members.json
                            withCredentials([string(credentialsId: 'gh-token-for-metadata-update', variable: 'GITHUB_TOKEN')]) {
                                sh "./_scripts/update-members.sh"
                            }

                            // Check if members.json changed
                            def membersChanged = sh(script: 'git diff --quiet _data/members.json', returnStatus: true) != 0

                            if (membersChanged) {
                                print "INFO: members.json changed, committing and pushing, then skipping build (will trigger a new build)"
                                withCredentials([gitUsernamePassword(credentialsId: 'username-and-token.Hibernate-CI.github.com', gitToolName: 'Default')]) {
                                    sh '''
                                        git config --global user.name 'Hibernate-CI'
                                        git config --global user.email 'ci@hibernate.org'
                                        git add _data/members.json
                                        git commit -m "Update members.json"
                                        git push origin HEAD:${BRANCH_NAME}
                                    '''
                                }
                                print "INFO: members.json pushed, skipping the rest of this build in favor of the next build triggered by this push"
                                currentBuild.getRawBuild().getExecutor().interrupt(Result.NOT_BUILT)
                                sleep(5)   // Interrupt is not blocking and does not take effect immediately.
                                return
                            }

                            print "INFO: members.json unchanged, continuing with build"
                        }
                    }
                }
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
