#!/bin/bash

source $(dirname $BASH_SOURCE)/util.sh

function get_plugin_name() {
	echo ${plugin_name:-"unknown"}
}

function plugin_debug() {
	local msg=$1
	shift
	log_debug "plugin[<y>$(get_plugin_name)</>] - $msg" "$@"
}

function plugin_info() {
	local msg="$1"
	shift
	log_info "plugin[<y>$(get_plugin_name)</>] - $msg" "$@"
}

function plugin_warn() {
	local msg="$1"
	shift
	log_warn "plugin[<y>$(get_plugin_name)</>] - $msg" "$@"
}

function plugin_error() {
	local msg="$1"
	shift
	log_error "plugin[<y>$(get_plugin_name)</>] - $msg" "$@"
}

# plugin_exit_error [<int: exit_code = $EX_ERR>] <error>
function plugin_exit_error() {
	local err=$1
	if [[ $(is_exit_code "$err") ]]; then
		shift
	else
		err=$EX_ERR
	fi
	exit_code $err plugin_error "$@"
}

# plugin_exit_erron <int: condition> [<int: exit_code = $EX_ERR>] <error>
function plugin_exit_erron() {
	local err=$1
	shift
	if [[ $err -ne 0 ]]; then
		plugin_exit_error "$@"
	fi
}

function plugin_arg() {
	return 0
}

function plugin_init() {
	return 0
}

function plugin_usage() {
	color_log "<g>  %s [\<options>]" "$(get_plugin_name)"
}

function plugin_options() {
	return 0
}

function print_usage() {
	color_log "<p>Usage"

	plugin_usage

	color_log "<p>Plugin Options"

	plugin_options

	color_log "<g>  -d,--dry-run                  [enable] Skip publishing, default: <y>false</>
  --debug                       [enable] Enable debug logging, default: <y>false</>
  --no-color                    [enable] Disable the color output, default: <y>false</>
  -h,--help                     Print usage"
}

function bad_option() {
	plugin_error "$@"
	print_usage
	exit $EX_ERR
}

function plugin_state() {
	if [[ $DEBUG ]]; then
		color_log "<g>  Git repository URL            <y>%s</>
  Git branch name               <y>%s</>
  Git tag prefix                <y>%s</>
  Git tag name                  <y>%s</>
  Version                       <y>%s</>
  Channel                       <y>%s</>
  Pre-release                   <y>%s</>
  Git last tag name             <y>%s</>
  Rlease Note                   <y>%s</>
  Dry Run                       <y>%s</>" \
			"$git_repo" \
			"$branch" \
			"$tag_prefix" \
			"$tag" \
			"$version" \
			"$channel" \
			"$prerelease" \
			"$prev_tag" \
			"${release_note:+"***"}" \
			"${dry_run:-"false"}"
	fi
}

function bootstrap() {
	hook=
	env_file=
	git_repo=
	branch=
	tag_prefix=
	prev_tag=
	tag=
	version=
	channel=
	prerelease=
	release_note=
	dry_run=
	while [[ $1 ]]; do
		local i=1
		local arg="$1"
		shift
		case "$arg" in
		--hook) hook="$1" ;;
		--env) env_file="$1" ;;
		--git-repo) git_repo="$1" ;;
		--branch) branch="$1" ;;
		--tag-prefix) tag_prefix="$1" ;;
		--prev-tag) prev_tag="$1" ;;
		--tag) tag="$1" ;;
		--version) version="$1" ;;
		--channel) channel="$1" ;;
		--pre-release) prerelease="$1" ;;
		--note) release_note="$1" ;;
		-d | --dry-run) dry_run="true" && i=0 ;;
		--debug) DEBUG="true" && i=0 ;;
		--no-color) COLOR_LOG= && i=0 ;;
		-h | --help)
			print_usage 1
			exit 0
			;;
		-*)
			plugin_arg "$arg" "$@"
			i=$?
			[[ $i -lt 0 ]] && plugin_exit_error "plugin_arg returned $i, should be >= 0"
			[[ $i -eq 0 ]] && bad_option "unknown option: $arg"
			((i--))
			;;
		*)
			plugin_arg "$arg" "$@"
			i=$?
			[[ $i -lt 0 ]] && plugin_exit_error "plugin_arg returned $i, should be >= 0"
			[[ $i -eq 0 ]] && bad_option "unknown command: $arg"
			((i--))
			;;
		esac

		for (( ; i > 0; i--)); do
			shift
		done
	done

	[[ ! $hook ]] && plugin_exit_error "invalid release context, miss the plugin hook"
	if [[ $hook == "load" ]]; then
		[[ ! $env_file ]] && plugin_exit_error "invalid release context, miss the output file of env"
	else
		[[ ! $git_repo ]] && plugin_exit_error "invalid release context, miss the git repository URL"
		[[ ! $branch ]] && plugin_exit_error "invalid release context, miss the git branch"

		hook=${hook/-/_}
		if [[ $hook == *"deploy" || $hook == "deploy-failed" ]]; then
			[[ ! $tag ]] && plugin_exit_error "invalid release context, miss the release git tag"
			[[ ! $version ]] && plugin_exit_error "invalid release context, miss the release version"
		fi
	fi

	plugin_init "$hook"
	local cmd=$(get_var "plugin_$hook")
	if [[ "$cmd" ]]; then
		plugin_debug "executing <y>%s</>: <w>%s" "$hook" "$cmd"
		eval "$cmd"
		plugin_exit_erron $? "execute <y>%s</>: <w>%s</> with error: $?" "$hook" "$cmd"
	fi
}
