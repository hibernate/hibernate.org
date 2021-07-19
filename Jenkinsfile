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
                // Clone hibernate.github.io in _publish_tmp if not present.
                // Using _tmp would mean more headaches related to access rights from the container,
                // which usually removes that dir in "rake clean": let's avoid that.
                dir ('_publish_tmp/hibernate.github.io') {
                    script {
                        checkout changelog: false, poll: false,
                                scm: [$class           : 'GitSCM', branches: [[name: '*/main']],
                                      extensions       : [[$class      : 'CloneOption',
                                                           depth       : 1,
                                                           honorRefspec: true,
                                                           noTags      : true,
                                                           reference   : '',
                                                           shallow     : true]],
                                      userRemoteConfigs: [[credentialsId: 'username-and-token.Hibernate-CI.github.com',
                                                           url          : 'https://github.com/hibernate/hibernate.github.io.git']]]
                    }
                }
                sh '_scripts/publish-to-production.sh'
            }
        }
    }
    post {
        always {
            zulipNotification smartNotification: 'disabled', stream: 'hibernate-infra', topic: 'activity'
        }
    }
}
