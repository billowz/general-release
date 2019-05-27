#!/bin/bash

# https://www.appveyor.com/docs/environment-variables
# https://www.appveyor.com/docs/build-worker-api

source $(dirname $BASH_SOURCE)/../lib/plugin.sh

plugin_name="appveyor"

function plugin_init() {
	if [[ $APPVEYOR ]]; then
		plugin_version="build_details"
	else
		exit_code plugin_debug "miss appveyor context"
	fi
}

function build_details() {
	plugin_debug "generating the build details on appveyor ..."

	local base=${prev_tag:-"${tag_prefix}0.0.0"}
	local msg="Develop Test on $base"
	local version="$base - $APPVEYOR_BUILD_NUMBER"
	if [[ $APPVEYOR_PULL_REQUEST_NUMBER ]]; then
		msg="Develop Test for RP($APPVEYOR_PULL_REQUEST_NUMBER) on $base"
	elif [[ $APPVEYOR_REPO_TAG_NAME ]]; then
		msg="Release Test for $APPVEYOR_REPO_TAG_NAME"
	elif [[ $tag ]]; then
		msg="Release ${tag}${prev_tag:+" <- $prev_tag"}"
	fi
	appveyor AddMessage "$msg"

	plugin_debug "updating build details, version: <y>%s</>, message: <y>%s</> ..." \
		"$version" \
		"$msg"

	appveyor UpdateBuild -Version "$version"
	appveyor UpdateBuild -Message "$msg"

	plugin_info "generated build details, version: <y>%s</>, message: <y>%s</> on appveyor" \
		"$version" \
		"$msg"
}

bootstrap "$@"
