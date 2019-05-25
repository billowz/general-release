#!/bin/bash

source $(dirname $BASH_SOURCE)/yaml.sh
source $(dirname $BASH_SOURCE)/util.sh

default_config_file="$(dirname $(dirname $BASH_SOURCE))/src/release.yml"
default_user_config_files=(".release.yml")
default_tag_prefix="v"
default_commit_message="chore(release): {tag} [skip ci]"
default_changelog="CHANGELOG.md"
default_commit_files=("$default_changelog")

commit_reg="^([a-zA-Z]+)(\(([a-zA-Z_-]+)\))?:\ (.+)$"

function __config_path() {
	echo "$1" | sed -e "s/release_//" -e "s/_\([0-9]\+\)_\?/[\1]/g" -e "s/_/./g"
}

function __read_config() {
	config_file="$1"

	if [[ ! $config_file ]]; then
		for i in "${default_user_config_files[@]}"; do
			if [[ -f $i ]]; then
				config_file="$i"
				break
			fi
		done
		: ${config_file:=$default_config_file}
	fi

	[[ ! -f $config_file ]] && exit_error "the config file: <y>%s</> is not exist" "$config_file"

	# load config
	log_debug "loading the config file: <y>%s" "$config_file"

	yaml $config_file "release_"
}

function __parse_config_rule() {
	local i="$1"
	[[ ! $(get_var $i type) ]] &&
		exit_error "invalid config: <y>%s</>, miss the rule type at %s" \
			"$config_file" \
			"$(__config_path $i)"

	if [[ ! $(get_var $i scope) ]]; then
		declare -g "${i}_scope"=".*"
	fi

	local release="$(get_var $i release)"
	if [[ $release ]]; then
		case "$release" in
		major) ;;
		minor) ;;
		patch) ;;
		none) declare -g "${i}_release"="" ;;
		*) exit_error "invalid config: <y>%s</>, unsupported release type: <y>%s</> on <y>%s</> at %s" \
			"$config_file" \
			"$release" \
			"$(get_var $i type)" \
			"$(__config_path $i)" ;;
		esac
	fi

	local prerelease="$(get_var $i prerelease)"
	if [[ $prerelease ]]; then
		case "$prerelease" in
		major) ;;
		minor) ;;
		patch) ;;
		prerelease) ;;
		none) declare -g "${i}_prerelease"="" ;;
		*) exit_error "invalid config: <y>%s</>, unsupported prerelease type: <y>%s</> on <y>%s</> at %s" \
			"$config_file" \
			"$prerelease" \
			"$(get_var $i type)" \
			"$(__config_path $i)" ;;
		esac
	else
		declare -g "${i}_prerelease"="prerelease"
	fi

	if [[ "$(get_var $i note)" ]]; then
		if [[ "$(get_var $i body)" != "true" ]]; then
			declare -g "${i}_body"=
		fi
	fi
}

function __print_release_rules() {
	local ident="$1"
	log "$ident<g>Rules: "
	log "$ident  <w>%-20s %-25s %-15s %-18s %-30s %s" \
		"Type Pattern" "Scope Pattern" "Release Type" "Prerelease Type" "Release Note" "Include Body"
	for i in "${release_rules_[@]}"; do
		local release="$(get_var $i release)"
		local prerelease="$(get_var $i prerelease)"
		local body="$(get_var $i body)"
		log "$ident  <g>%-20s %-25s <y>%-15s %-18s</> %-30s %s" \
			"$(get_var $i type)" \
			"$(get_var $i scope)" \
			"${release:-"none"}" \
			"${prerelease:-"none"}" \
			"$(get_var $i note)" \
			"${body:-"false"}"
	done
}

function load_config_rules() {
	__read_config "$1"
	for i in "${release_rules_[@]}"; do
		__parse_config_rule "$i"
	done

	# print logger
	log_info "loaded config file: <y>%s" "$config_file"
	if [[ $DEBUG ]]; then
		log_debug "Configurations:"
		__print_release_rules "  "
	fi
}

# load release configuration
function load_config() {
	__read_config "$1"

	# parse branch config
	for i in "${release_branchs_[@]}"; do
		[[ ! "$(get_var $i pattern)" ]] &&
			exit_error "invalid config: <y>%s</>, miss the branch pattern at %s" \
				"$config_file" \
				"$(__config_path $i)"

		if [[ "$(get_var $i channel)" == "latest" ]]; then
			declare -g "${i}_channel"=
		fi
	done

	# parse release/note rule config
	release_items=()
	prerelease_items=()
	note_items=()
	note_titles=()
	for i in "${release_rules_[@]}"; do
		__parse_config_rule "$i"

		if [[ "$(get_var $i release)" ]]; then
			release_items+=($i)
		fi
		if [[ "$(get_var $i prerelease)" ]]; then
			prerelease_items+=($i)
		fi
		local title="$(get_var $i note)"
		if [[ $title ]]; then
			local idx=0
			for (( ; idx < ${#note_titles[@]}; idx++)); do
				if [[ ${note_titles[idx]} == $title ]]; then
					break
				fi
			done
			declare -g "${i}_notei"=$idx
			note_titles[$idx]="$title"
			note_items+=($i)
		fi
	done

	: ${release_git_repo:=$(git config --get remote.origin.url | sed -e "s/\.git$//" -e "s|^git@\([^:]+\):|https://\1|")}
	: ${release_tag_prefix:=$default_tag_prefix}
	: ${release_changelog:=$default_changelog}
	: ${release_commit_message:=$default_commit_message}

	if [[ ${#release_commit_[@]} -gt 0 ]]; then
		release_commit_files=()
		for i in "${release_commit_[@]}"; do
			release_commit_files+=("$(get_var $i)")
		done
	else
		release_commit_files=("${default_commit_files}")
	fi

	if [[ $release_commit_note == "false" ]]; then
		release_commit_note=
	else
		release_commit_note="true"
	fi

	release_plugins=()
	release_plugin_labels=()
	for i in "${release_plugins_[@]}"; do
		local plugin="$(get_var $i)"
		release_plugins+=("$(get_var $i)")
		release_plugin_labels+=("${plugin/ */}")
	done

	# print logger
	log_info "loaded config file: <y>%s" "$config_file"
	if [[ $DEBUG ]]; then
		log_debug "Configurations:
  git-repo:                     <y>%s</>
  tag-prefix:                   <y>%s</>
  changelog:                    <y>%s</>
  commit:                       <y>%s</>
  commit-message:               <y>%s</>
  commit-note:                  <y>${release_commit_note:-"false"}</>
  plugins:                      <y>%s" \
			"${release_git_repo}" \
			"${release_tag_prefix}" \
			"$release_changelog" \
			"$(join ", " "${release_commit_files[@]}")" \
			"${release_commit_message}" \
			"$(join ", " "${release_plugin_labels[@]}")"
		log "  <g>Branchs:"
		log "    <w>%-50s  %-20s %s" "Branch Pattern" "Channel" "Pre-release"
		for i in "${release_branchs_[@]}"; do
			local channel="$(get_var $i channel)"
			log "    <g>%-50s  <y>%-20s %s" "$(get_var $i pattern)" "${channel:-"latest"}" "$(get_var $i prerelease)"
		done
		__print_release_rules "  "
	fi
}

function __parse_types() {
	for i in "${release_rules_[@]}"; do
		local type="$(get_var $i type)"
		if [[ $type =~ ^[a-zA-Z]+$ && ! "$(get_var "types_${type}__")" ]]; then
			echo "$type"
			declare -g "types_${type}__"="true"
		fi
	done
}

function validate_message() {
	local message="$1"

	if [[ ! $message ]]; then
		exit_code 1 log "<r>✗   empty message header
<r>✗   the message header must be:<w>
    \<type>(\<scope>): \<subject>
    \<body>" "$line"
	fi

	if [[ $message =~ ^Merge ]]; then
		exit_code log "<g>✓   %s" "$message"
	fi

	local first_line="true"
	while read -r line; do
		if [[ $line =~ $commit_reg ]]; then
			local type="${BASH_REMATCH[1]}"
			local scope="${BASH_REMATCH[3]}"
			local subject="${BASH_REMATCH[4]}"
			local rule=

			for i in "${release_rules_[@]}"; do
				if [[ $type =~ ^$(get_var $i type)$ ]]; then
					rule=$i
				fi
			done

			if [[ ! $rule ]]; then
				exit_code 1 log "<r>⚐   <w>%s
<r>✗   the message type(<w>%s</>) must be one of: <w>%s" \
					"$line" "$type" "$(echo $(__parse_types) | sed "s/ / | /g")"
			fi

			log "<g>✓   %s" "$line"

			first_line=

		elif [[ $first_line ]]; then
			if [[ "$line" ]]; then
				exit_code 1 log "<r>⚐   <w>%s
<r>✗   the message format must be:<w>
    \<type>(\<scope>): \<subject>
    \<body>" "$line"
			else
				exit_code 1 log "<r>✗   empty message header
<r>✗   the message header must be:<w>
    \<type>(\<scope>): \<subject>
    \<body>" "$line"
			fi
		fi
	done <<<"$message"
}

function generate_message_template() {
	echo "
# Commit Format
#   <type>(<scope>): <subject>
#   <body>
#
# head
#   - type: $(echo $(__parse_types) | sed "s/ /, /g")
#   - scope: can be empty (eg. if the change is a global or difficult to assign to a single component)
#   - subject: start with verb (such as 'change'), 50-character line
# body
#   72-character wrapped. This should answer:
#     - Why was this change necessary?
#     - How does it address the problem?
#     - Are there any side effects?
# Rules"

	printf "#  %-20s %-25s %-15s %-30s %s\n" \
		"Type Pattern" "Scope Pattern" "Release Type" "Release Note" "Include Body"
	for i in "${release_rules_[@]}"; do
		local r="$(get_var $i release)"
		local b="$(get_var $i body)"
		printf "#  %-20s %-25s %-15s %-30s %s\n" \
			"$(get_var $i type)" \
			"$(get_var $i scope)" \
			"${r:-"none"}" \
			"$(get_var $i note)" \
			"${b:-"false"}"
	done
	echo "#"
}
