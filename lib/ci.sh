#!/bin/bash

source $(dirname $BASH_SOURCE)/util.sh

function load_ci() {
	ci=

	# https://www.appveyor.com/docs/environment-variables/
	if [[ $APPVEYOR ]]; then
		ci="Appveyor"
		branch="$APPVEYOR_REPO_BRANCH"
		rp="$APPVEYOR_PULL_REQUEST_NUMBER"
	# https://docs.travis-ci.com/user/environment-variables
	elif [[ $TRAVIS ]]; then
		ci="Travis"
		branch="$TRAVIS_BRANCH"
		rp="$TRAVIS_PULL_REQUEST"
	# https://circleci.com/docs/1.0/environment-variables
	elif [[ $CIRCLECI ]]; then
		ci="CircleCI"
		branch="$CIRCLE_BRANCH"
		rp="$CI_PULL_REQUEST"
	# https://docs.gitlab.com/ce/ci/variables/README.html
	elif [[ $GITLAB_CI ]]; then
		ci="GitlabCI"
		branch="$CI_COMMIT_REF_NAME"
	# https://wiki.jenkins.io/display/JENKINS/Building+a+software+project
	elif [[ $JENKINS_URL ]]; then
		ci="Jenkins"
		branch="$GIT_BRANCH"
	fi

	if [[ $ci ]]; then
		log_debug "CI: <y>$ci</>, branch: $branch, rp: $rp"
	fi
}
