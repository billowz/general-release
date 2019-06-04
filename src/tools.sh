#!/bin/bash

root_dir="$(dirname "$(dirname $BASH_SOURCE)")"
source $root_dir/lib/git.sh
source $root_dir/lib/config.sh

commit_lint_hook_file=".git/hooks/commit-msg"
default_template_file=".gitmessage"

hook_head="# general-release"
function generate_commit_linter() {
	echo "#!/bin/sh
$hook_head
# Hook created by general-release
#   See: https://github.com/tao-zeng/general-release#readme

source ${root_dir//\\//}/lib/config.sh"
	echo 'msg="$(cat $1)"'
	printf "\n# Define Release Rules from %s" "$config_file"

	for i in "${release_rules_[@]}"; do
		echo "${i}_type=\"$(get_var $i type)\""
	done
	echo "release_rules_=(${release_rules_[@]})"
	echo -e "\n\n# validate message\nvalidate_message \"\$msg\""
}

function bad_option() {
	log_error "$@"
	print_usage
	exit $EX_ERR
}

function print_usage() {
	color_log "<p>Usage"
	if [[ ! $cmd || $cmd == "install" ]]; then
		color_log "  <g>%s install [\<options>]" "$BASH_SOURCE"
	fi
	if [[ ! $cmd || $cmd == "uninstall" ]]; then
		color_log "  <g>%s uninstall [\<options>]" "$BASH_SOURCE"
	fi
	color_log "<p>Options"
	if [[ $cmd ]]; then
		if [[ $cmd == "install" ]]; then
			color_log "  <g>-c,--config                   [string] Release config file(.yml), default: <y>%s, %s</>
  -o,--template                 [string] Output message template file, default: <y>%s</>" \
				"$(join ", " "${default_user_config_files[@]}")" \
				"$root_dir/src/release.yml" \
				"$default_template_file"
		fi
		color_log "  <g>--commit-lint                 [enable] Specify the commit linter to $cmd, default: <y>false</>
                                         Would $cmd all tools(commit-lint and commit-template) at No tool is specified
  --commit-template             [enable] Specify the commit template to $cmd, default: <y>false</>
                                         Would $cmd all tools(commit-lint and commit-template) at No tool is specified
  --debug                       [enable] Enable debug logging, default: <y>false</>
  --no-color                    [enable] Disable the color template, default: <y>false</>"
	fi
	color_log "  <g>-h,--help                     Print usage"
}

cmd="$1"
shift
[[ $cmd == "-h" || $cmd == "--help" ]] && cmd= && print_usage && exit 0
[[ ! $cmd =~ ^(install|uninstall)$ ]] && bad_option "unknown command: $cmd"

config_file=
template_file=

config_tools=
tool_commit_lint=
tool_commit_template=
while [[ $1 ]]; do
	i=1
	arg="$1"
	shift
	case "$arg" in
	-c | --config)
		[[ $cmd == "uninstall" ]] && bad_option "unknown option: $arg"
		config_file="$1"
		;;
	--template)
		[[ $cmd == "uninstall" ]] && bad_option "unknown option: $arg"
		template_file="$1"
		;;
	--commit-lint) config_tools="true" && tool_commit_lint="true" && i=0 ;;
	--commit-template) config_tools="true" && tool_commit_template="true" && i=0 ;;
	--debug) DEBUG="true" && i=0 ;;
	--no-color) COLOR_LOG= && i=0 ;;
	-h | --help)
		print_usage
		exit 0
		;;
	-*) bad_option "unknown option: $arg" ;;
	*) bad_option "unknown command: $arg" ;;
	esac
	for (( ; i > 0; i--)); do
		shift
	done
done

: ${template_file:="$default_template_file"}

if [[ ! $config_tools ]]; then
	tool_commit_lint="true"
	tool_commit_template="true"
fi

if [[ $cmd == "install" ]]; then
	load_config_rules "$config_file"

	if [[ $tool_commit_template ]]; then
		log_debug "generating commit template: <y>%s</> ..." "$template_file"

		echo "$(generate_message_template)" >$template_file
		git config --local commit.template $template_file

		log_info "installed commit template: <y>%s" "$template_file"
	fi

	if [[ $tool_commit_lint ]]; then
		log_debug "installing commit linter: <y>%s</> ..." "$commit_lint_hook_file"

		echo "$(generate_commit_linter)" >$commit_lint_hook_file

		log_info "installed commit linter: <y>%s" "$commit_lint_hook_file"
	fi
else
	if [[ $tool_commit_template ]]; then
		git config --local commit.template ""
		log_info "uninstalled commit template"
	fi

	if [[ $tool_commit_lint ]]; then
		if [[ -f $commit_lint_hook_file && $(cat $commit_lint_hook_file | sed -n '2p') == $hook_head ]]; then
			rm -f $commit_lint_hook_file
			log_info "uninstalled commit linter: %s" "$commit_lint_hook_file"
		else
			log_info "no installed commit linter: %s" "$commit_lint_hook_file"
		fi
	fi
fi
