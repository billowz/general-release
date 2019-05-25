#!/bin/bash

source $(dirname $BASH_SOURCE)/../lib/plugin.sh

plugin_name="github"
plugin_before_deploy="print_state && init && check_auth"
plugin_deploy="init && deploy"

token="$GITHUB_TOKEN"
files=()

function plugin_arg() {
	case "$1" in
	-t | --token)
		token="$2"
		return 2
		;;
	-f | --file)
		files+=("$2")
		return 2
		;;
	esac
	return 0
}

function plugin_usage() {
	color_log "<g>  -f,--file                     [string] Add a publish file
  -t,--token                    [string] GitHub auth token, default: <y>ENV:GITHUB_TOKEN</>"
}

function print_state() {
	plugin_debug "Options:<g>
  files                         <y>%s</>%s" \
		"$(join ", " "${files[@]}")" \
		"$(plugin_state)"
}

function init() {
	pre="false"
	if [[ $prerelease ]]; then
		pre="true"
	fi
	if [[ ! $token ]]; then
		plugin_exit_error "miss the Github Token (env: GITHUB_TOKEN)"
	fi
	release_api="$(echo $git_repo | sed "s|github\.com/|api.github.com/repos/|")/releases"
	upload_api="$(echo $git_repo | sed "s|github\.com/|uploads.github.com/repos/|")/releases"
}

function request() {
	local url="$1"
	local success_code="$2"
	local msg="$3"
	shift 3
	local rs=$(curl -s -w "\n%{http_code}\n" -H "Authorization: token $token" "$@" "$url")
	local code="$(echo "$rs" | tail -1)"
	if [ $code != $success_code ]; then
		plugin_exit_error "$msg with error: $code\n%s" "$rs"
	fi
	echo "$rs"
}

function upload() {
	local id="$1"
	local file="$2"
	local name="$(basename $file)"
	local size="$(stat -c '%s' "$file")"
	local url="$upload_api/$id/assets?name=$name&size=$size"
	local content_type="$(file --mime-type -b "$file")"
	if [[ ! $content_type ]]; then
		plugin_warn "can not get the content-type on %s" "$file"
	fi

	plugin_debug "uploading <y>%s</> to <y>%s</> ..." "$file" "$url"

	request "$url" "201" \
		"$(log "upload <y>%s</> to <y>%s</>" "$file" "$url")" \
		-H "Accept: application/vnd.github.manifold-preview" \
		-H "Content-Type: $content_type" \
		--data-binary "@$file" 1>/dev/null
}

function check_auth() {
	for i in $files; do
		[[ ! -f $i ]] && plugin_exit_error "%s is not exist" "$i"
	done

	git config --global credential.helper store
	echo -e "https://$token:x-oauth-basic@github.com" >>~/.git-credentials
	return 0
}

function deploy() {
	if [[ $dry_run ]]; then
		return 0
	fi

	plugin_debug "creating github draft release: <y>%s</> on <y>%s</> ..." "$tag" "$release_api"

	local rs=$(request "$release_api" "201" \
		"$(log "create draft release on <y>%s</>" "$release_api")" \
		-d "{
	\"tag_name\": \"$tag\",
	\"target_commitish\": \"$branch\",
	\"name\": \"$tag\",
	\"draft\": true,
	\"body\": \"$(echo "$release_note" | sed -e 's/"/\\"/g' -e 's/\\n/\\\\n/g' | sed ':a;N;$!ba;s/\n/\\n/g')\",
	\"prerelease\": $pre
}")
	local id=$(echo "$rs" | sed -ne 's/^  "id": \(.*\),$/\1/p')
	if [[ -z "$id" ]]; then
		plugin_exit_error "create draft release on <y>%s</> with error: miss the release id\n%s" \
			"$release_api" \
			"$rs"
	fi

	if [[ ${#files[@]} > 0 ]]; then
		plugin_debug "uploading files on the release: <y>%s</> ..." "$id"
		for i in $files; do
			upload $id $i
		done
	else
		plugin_debug "no file on the release: <y>%s</> ..." "$id"
	fi

	plugin_debug "publishing github release: <y>%s</> - <y>%s</> to <y>%s/%s</> ..." \
		"$id" "$tag" "$release_api" "$id"

	request "$release_api/$id" "200" \
		"$(log "publish github release: <y>%s</> - <y>%s</> to <y>%s/%s</>" \
			"$id" "$tag" "$release_api" "$id")" \
		-d "{\"draft\": false}" 1>/dev/null

	plugin_info "published github release: <y>%s</> - <y>%s</> to <y>%s/%s</> ..." \
		"$id" "$tag" "$release_api" "$id"
}

bootstrap "$@"
