#!/bin/bash

source $(dirname $BASH_SOURCE)/../lib/plugin.sh

plugin_name="npm"
plugin_before_deploy="print_state && init && update_version"
plugin_deploy="init && deploy"

default_registry='https://registry.npmjs.org/'
default_access='public'

if ! [ -x "$(command -v npm)" ]; then
	plugin_exit_error "you need to install the npm"
fi

package_info=($(node -p "
var pkg = require('./package.json');
var cfg = pkg.publishConfig;
[
    pkg.name,
    (cfg && cfg.registry) || '$default_registry',
    (cfg && cfg.access) || '$default_access'
].join(' ')"))

package_name="${package_info[0]}"
registry="${package_info[1]}"
access="${package_info[2]}"
token="${NPM_TOKEN}"

function plugin_arg() {
	case "$1" in
	-r | --registry)
		registry="$2"
		return 2
		;;
	-a | --access)
		access="$2"
		return 2
		;;
	-t | --token)
		token="$2"
		return 2
		;;
	esac
	return 0
}

function plugin_options() {
	color_log "<g>  -r,--registry                 [string] NPM registry URL, default: <y>%s</>
  -a,--access                   [string] Package access, default: <y>%s</>
  -t,--token                    [string] NPM auth token, default: <y>ENV:NPM_TOKEN</>" \
		"$default_registry" \
		"$default_access"
}

function print_state() {
	plugin_debug "Options:<g>
  npm registry                  <y>%s</>
  npm access                    <y>%s</>" \
		"$registry" \
		"$access"
	plugin_state
}

function init() {
	if [[ ! $registry ]]; then
		bad_option "miss the npm registry"
	fi
	if [[ ! $access ]]; then
		bad_option "miss the npm access"
	fi

	package="$package_name@$version"
	if [[ $token ]]; then
		plugin_debug "setting the token of <y>%s</> ..." "$registry"

		npm config set "${registry/*:/}:_authToken" "$token"
	fi
}

function update_version() {
	plugin_debug "checking auth on <y>%s</> ..." "$registry"

	auth=$(npm whoami --registry $registry)

	plugin_exit_erron $? "no auth on <y>%s</>" "$registry"

	plugin_debug "checking the npm package: <y>%s</> on <y>%s</> by <y>$auth</> ..." "$package" "$registry"

	if [[ "$(npm view $package version --registry $registry 2>/dev/null)" ]]; then
		plugin_exit_error "the npm package: <y>%s</> is exist" "$package"
	fi

	plugin_debug "updating version in <y>package.json</> by <y>$auth</> ..."

	npm --no-git-tag-version --force --allow-same-version version $version 2>/dev/null
}

function deploy() {
	plugin_debug "publishing npm package <y>%s</> by <y>$auth</> ..." "$package"

	local out=
	out=$(npm publish --tag ${channel:-"latest"} --access $access ${dry_run:+"--dry-run"} --registry "$registry" 2>&1)
	local err=$?

	plugin_exit_erron $err "publish npm package <y>%s</> by <y>$auth</> with error: $err\n%s" "$package" "$out"
	plugin_info "published npm package <y>%s</> by <y>$auth</>\n<w>%s" "$package" "$out"
}

bootstrap "$@"
