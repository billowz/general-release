#!/bin/bash

source $(dirname $BASH_SOURCE)/../lib/plugin.sh

plugin_name="gzip"
plugin_before_deploy="print_state && gzip"

files=()
output=
function plugin_arg() {
	case "$1" in
	-o | --output)
		output="$2"
		return 2
		;;
	*)
		files+=("$1")
		return 1
		;;
	esac
	return 0
}

function plugin_usage() {
	color_log "<g>  %s [\<options>] [\<path>...]" "$plugin_name"
}

function plugin_options() {
	color_log "<g>  -o,--output                   [string] Write the archive to this file"
}

function print_state() {
	plugin_debug "Options:<g>
  output                        <y>%s</>
  files                         <y>%s</>" "$output" "$(join ", " "${files[@]}")"
	plugin_state
}

function gzip() {
	[[ ! $output ]] && plugin_exit_error "miss the output file"
	[[ ${#files[@]} -eq 0 ]] && plugin_exit_error "miss the archive file"

	plugin_debug "archiving <y>%s</>" "$output"
	log=$(tar -zcvf $output "${files[@]}" 2>&1)

	plugin_exit_erron $? "archive <y>%s</> with error: $?\n<w>%s" "$output" "$log"
	plugin_info "archived <y>%s</>" "$output"
}

bootstrap "$@"
