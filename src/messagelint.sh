#!/bin/bash

root_dir="$(dirname "$(dirname $BASH_SOURCE)")"
source $root_dir/lib/util.sh
source $root_dir/lib/config.sh

function print_usage() {
	color_log "<p>Usage<g>
  %s [\<options>] \<message>
<p>Options<g>
  -c,--config                   [string] Release config file(.yml), default: <y>%s, %s</>
  --debug                       [enable] Enable debug logging, default: <y>false</>
  --no-color                    [enable] Disable the color output, default: <y>false</>
  -h,--help                     Print usage" \
		"$BASH_SOURCE" \
		"$(join ", " "${default_user_config_files[@]}")" \
		"$root_dir/src/release.yml"
}

function bad_option() {
	log_error "$@"
	print_usage
	exit $EX_ERR
}

config_file=
message=
while [[ $1 ]]; do
	i=1
	arg="$1"
	shift
	case "$arg" in
	-c | --config) config_file="$1" ;;
	--debug) DEBUG="true" && i=0 ;;
	--no-color) COLOR_LOG= && i=0 ;;
	-h | --help)
		print_usage
		exit 0
		;;
	-*) bad_option "unknown option: $arg" ;;
	*)
		if [[ $message ]]; then
			message="$message
$arg"
		else
			message="$arg"
		fi
		i=0
		;;
	esac
	for (( ; i > 0; i--)); do
		shift
	done
done

load_config_rules "$config_file"
validate_message "$message"
