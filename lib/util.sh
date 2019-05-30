#!/bin/bash

EX_ERR=1

# get_var(<name>, [<sufix>])
function get_var() {
	local name="$1${2:+"_$2"}"
	echo "${!name}"
}

# join(<element>...)
function join() {
	local c="$1"
	shift
	local first="true"
	for i in "$@"; do
		if [[ $first ]]; then
			first=
		else
			echo -n "$c"
		fi
		echo -n "$i"
	done
}

# to_str(<fmt>, ...)
function to_str() {
	local fmt="$1"
	shift
	for i in "$@"; do
		printf "$fmt" "$i"
	done
}

# format(<message>, [<fmt key>, <value>]...)
function format() {
	local msg="$1"
	shift
	while [[ $1 ]]; do
		msg=$(echo $msg | awk -v value="$2" "{gsub(/{$1}/, value); print}")
		shift
		shift
	done
	echo $msg | sed 's/\\{/{/g'
}

function escape() {
	local input=${1:-$(</dev/stdin)}
	echo $(echo "$input" | sed "s/\([+()\\\/]\)/\\\\\1/g")
}

##################################
# log
##################################

color_normal="\033[00m"
color_black="\033[30;01m"
color_red="\033[31;01m"
color_green="\033[32;01m"
color_yellow="\033[33;01m"
color_blue="\033[34;01m"
color_purple="\033[35;01m"
color_cyan="\033[36;01m"
color_white="\033[37;01m"
color_r=$color_red
color_g=$color_green
color_b=$color_cyan
color_y=$color_yellow
color_p=$color_purple
color_w=$color_white
color_n=$color_normal

function parse_log() {
	local msg=$(echo "$1" | sed -e 's/\(^\|[^\\]\)\(<\/[a-zA-Z]*>\|<[a-zA-Z]\+>\)/\1/g' -e 's/\\</</g')
	shift
	printf "$msg\n" "$@" >&1
}

#              1 2                        3   45           6
color_log_reg='(<(\/[a-zA-Z]*|[a-zA-Z]+)>|(.))((\\.|[^<])*)(.*)'
function color_log() {
	local input="$1"
	local msg=""
	local c=""
	local prev_c="white"
	local current_c="$prev_c"
	shift
	while [[ $input && $input =~ $color_log_reg ]]; do
		c=${BASH_REMATCH[2]}
		if [[ $c ]]; then
			if [[ $c == '/'* ]]; then
				c=$prev_c
			else
				prev_c=$current_c
			fi
			current_c=$c
			c="color_$c"
			if [[ ! "${!c}" ]]; then
				printf "invalid color: %s\n" $current_c >&2
				exit $EX_ERR
			fi
			msg="${msg}${!c}"
		fi
		msg="${msg}${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
		input="${BASH_REMATCH[6]}"
	done
	printf "${color_white}$(echo "${msg}${input}" | sed 's/\\</</g')\n${color_white}" "$@" >&1
}

COLOR_LOG="yes"

function log() {
	local msg=$1
	shift
	if [[ $COLOR_LOG ]]; then
		color_log "$msg" "$@"
	else
		parse_log "$msg" "$@"
	fi
}

function log_debug() {
	if [[ $DEBUG ]]; then
		local msg=$1
		shift
		log "[<g>debug</>] <g>general-release - $msg" "$@"
	fi
}

function log_info() {
	local msg="$1"
	shift
	log "[<b> info</>] <b>general-release - $msg" "$@"
}

function log_warn() {
	local msg="$1"
	shift
	log "[<y> warn</>] <y>general-release - $msg" "$@"
}

function log_error() {
	local msg="$1"
	shift
	log "[<r>error</>] <r>general-release - $msg" "$@" >&2
}

time_depth=0
function start_time() {
	declare -g "time_$time_depth"=$(date +%s)
	time_depth=$((($time_depth + 1)))
}

function end_time() {
	if [[ $time_depth -eq 0 ]]; then
		error "no started timer"
		exit $EX_ERR
	fi
	time_depth=$((($time_depth - 1)))
	local start_name="time_$time_depth"
	echo $(($(date +%s) - ${!start_name}))
}

function start_time_log() {
	start_time
	"$@"
}

function end_time_log() {
	"$@" "$(end_time)s"
}

function is_exit_code() {
	if [[ "$1" =~ ^[0-9]+$ && $1 -lt 256 ]]; then
		echo "true"
	fi
}

# exit_conde [<int: exit_code = 0>] [<cmd>]
function exit_code() {
	local code=$1
	if [[ $(is_exit_code "$code") ]]; then
		shift
	else
		code=0
	fi
	"$@"
	exit $code
}

# exit_on <int: condition> [<int: exit_code = 0>] [<cmd>]
function exit_on() {
	local cond=$1
	shift
	if [[ $cond -ne 0 ]]; then
		exit_code "$@"
	fi
}

# exit_error [<int: exit_code = $EX_ERR>] <error>
function exit_error() {
	local err=$1
	if [[ $(is_exit_code "$err") ]]; then
		shift
	else
		err=$EX_ERR
	fi
	exit_code $err log_error "$@"
}

# exit_erron <int: condition> [<int: exit_code = $EX_ERR>] <error>
function exit_erron() {
	local err=$1
	shift
	if [[ $err -ne 0 ]]; then
		exit_error "$@"
	fi
}
