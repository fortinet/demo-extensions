node('devops-aws') {
    stage('Clean up') {
        sh 'rm -rf *'
    }

    stage('Checkout') {
        def changeBranch = "change-${GERRIT_CHANGE_NUMBER}-${GERRIT_PATCHSET_NUMBER}"
        def scmVars = checkout scm
        git url: scmVars.GIT_URL
        sh "git fetch origin ${GERRIT_REFSPEC}:${changeBranch}"
        sh "git checkout ${changeBranch}"
    }

    docker.image('eeacms/pep8').inside {
        stage('Lint') {
            echo 'Pylinting..'
            sh 'pep8 *.py'
        }
    }
}