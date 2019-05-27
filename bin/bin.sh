#!/bin/bash

root_dir="$(dirname "$(dirname $BASH_SOURCE)")"

source $root_dir/lib/util.sh

src_dir=$root_dir/src

echo "$BASH_SOURCE $@"

case "$1" in
-h | --help)
	color_log "<p>Usage<g>
  %s [deploy] [\<options>]
  %s preview [\<options>]
  %s validate [\<options>]
  %s install [\<options>]
  %s uninstall [\<options>]
<p>Options<g>
  -h,--help                     Print usage" \
		"$BASH_SOURCE" "$BASH_SOURCE" "$BASH_SOURCE" "$BASH_SOURCE" "$BASH_SOURCE"
	;;
install)
	shift
	sh "$src_dir/tools.sh" install "$@"
	;;
uninstall)
	shift
	sh "$src_dir/tools.sh" uninstall "$@"
	;;
validate)
	shift
	sh "$src_dir/messagelint.sh" "$@"
	;;
preview)
	shift
	sh "$src_dir/release.sh" "$@" --no-deploy
	;;
deploy)
	shift
	sh "$src_dir/release.sh" "$@"
	;;
*)
	sh "$src_dir/release.sh" "$@"
	;;
esac
