#!/bin/bash

source $(dirname $BASH_SOURCE)/util.sh

function load_ci() {
	# https://www.appveyor.com/docs/environment-variables/
	if [[ $APPVEYOR ]]; then
		log_debug ""
		branch="$APPVEYOR_REPO_BRANCH"
		rp="$APPVEYOR_PULL_REQUEST_NUMBER"
	# https://docs.travis-ci.com/user/environment-variables
	elif [[ $TRAVIS ]]; then
		branch="$TRAVIS_BRANCH"
		rp="$TRAVIS_PULL_REQUEST"
	# https://circleci.com/docs/1.0/environment-variables
	elif [[ $CIRCLECI ]]; then
		branch="$CIRCLE_BRANCH"
		rp="$CI_PULL_REQUEST"
	# https://wiki.jenkins.io/display/JENKINS/Building+a+software+project
	elif [[ $JENKINS_URL ]]; then
		branch="$GIT_BRANCH"
	fi
	return 0
}
