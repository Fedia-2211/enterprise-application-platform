// jenkins/jobs/gitea-deploy.groovy
// Jenkins Job DSL seed script — run this once to create the pipeline job
// In Jenkins: New Item > Freestyle > Build > Process Job DSLs > paste this

pipelineJob('gitea-deploy') {
    displayName('Gitea — Deploy to Production')
    description('Rolling deployment of Gitea to both app servers. Triggered by GitHub webhook on push to main.')

    properties {
        githubProjectUrl('https://github.com/YOUR_GITHUB_USERNAME/enterprise-application-platform')

        disableConcurrentBuilds()

        buildDiscarder {
            strategy {
                logRotator {
                    numToKeepStr('20')
                    artifactNumToKeepStr('5')
                }
            }
        }
    }

    triggers {
        githubPush()
        cron('H 2 * * 1') // Weekly scheduled check Monday 02:xx
    }

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://github.com/YOUR_GITHUB_USERNAME/enterprise-application-platform.git')
                        credentials('github-credentials')
                    }
                    branches('*/main')
                    extensions {
                        cleanBeforeCheckout()
                        cloneOptions {
                            shallow(true)
                            depth(5)
                        }
                    }
                }
            }
            scriptPath('jenkins/Jenkinsfile')
            lightweight(true)
        }
    }
}
