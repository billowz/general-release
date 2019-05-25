#!/bin/bash

root_dir="$(dirname "$(dirname $BASH_SOURCE)")"
source $root_dir/lib/git.sh
source $root_dir/lib/config.sh
source $root_dir/lib/ci.sh

# error code
EX_NORELEASE=3

num_reg="(0|[1-9][0-9]*)"
#             1                  2 3            4 5
version_reg="^(major|minor|patch|pre)(-([a-zA-Z]+))?(@([a-zA-Z]+))?$"
version_format_reg="<y>(major|minor|patch|pre)[-\<prerelease>][@\<channel>]</>"

# load default plugins
plugin_dir="${root_dir//\\//}/plugins"
default_plugins=()
for i in $plugin_dir/*.sh; do
	default_plugins+=("$(echo $i | sed "s/.*\/\(.\+\)\.sh/\1/g")")
done

function print_useage() {
	color_log "<p>Useage<g>
  %s [\<options>]
<p>Options<g>
  -c,--config                   [string] Release config file(.yml), default: <y>%s, %s</>
  --rp                          [string] Pull Request, will cancel deploy on Pull Request
  -b,--branch                   [string] Git branch to release from, default: <y>[auto]</>
                                         <w>get current branch with \`git rev-parse --abbrev-ref HEAD\`</>
  -v,--version                  [string] Release version, default: <y>[auto]</>
                                         <w>Syntax:</> $version_format_reg
                                                 <y>\<tag-prefix>{x}.{x}.{x}[-\<prerelease>.{x}][@\<channel>]</>
                                         <w>analyze the submissions after the last tag with the release rules defined in the configuration</>
  -r,--git-repo                 [string] Git repository URL, default: <y>[auto]</>
                                         <w>get repository url with \`git config --get remote.origin.url\`</>
  -t,--tag-prefix               [string] Git tag prefix, default: <y>\"%s\"</>
  --note                        [string] Release Note, default: <y>[auto]</>
                                         <w>analyze the submissions after the last tag with the note rules defined in the configuration</>
  --changelog                   [string] Generante the changelog file, default: <y>%s</>
  -a,--commit                   [string] Add a commit file, default commit files: <y>%s</y>
                                         <w>automatically commit when the file list is not empty</>
  --commit-message              [string] Commit message, default: <y>\"%s\"</>, format keys:
                                            <y>version</>: release version
                                            <y>channel</>: release channel
                                         <y>prerelease</>: prerelease prefix
                                                <y>tag</>: git tag name
  --no-commit-note              [enable] Commit without the release note, default: <y>false</>
  -p,--plugin                   [string] Add a plugin, the plugins: $(to_str "
                                         <y>%s [options]</>" "${default_plugins[@]}")
                                         <y>constum.sh [options]</>
  --no-deploy                   [enable] Preview release and skip deploy, default: <y>false</>
  -d,--dry-run                  [enable] Skip publishing, default: <y>false</>
  --debug                       [enable] Enable debug logging, default: <y>false</>
  --no-color                    [enable] Disable the color output, default: <y>false</>
  -h,--help                     Print useage" \
		"$BASH_SOURCE" \
		"$(join ", " "${default_user_config_files[@]}")" \
		"$root_dir/src/release.yml" \
		"$default_tag_prefix" \
		"$default_changelog" \
		"$(join ", " "${default_commit_files[@]}")" \
		"$default_commit_message"
}

function __load_plugins() {
	local hook="$1"
	local env_file=
	if [[ $hook == "load" ]]; then
		env_file=".release.env"
		if [[ -f $env_file ]]; then
			rm -f $env_file
		fi
	fi
	log_debug "loading plugins[<y>$hook</>]"
	for ((i = 0; i < ${#plugins[@]}; i++)); do
		${plugins[i]} --hook "$hook" \
			--env "$env_file" \
			--git-repo "$git_repo" \
			--branch "$branch" \
			--tag-prefix "$tag_prefix" \
			--prev-tag "$prev_tag" \
			--tag "$next_tag" \
			--version "$next_version" \
			--channel "$next_channel" \
			--pre-release "$next_pre" \
			--note "$release_note" \
			${dry_run:+'--dry-run'} \
			${no_color_log:+'--no-color'} \
			${DEBUG:+'--debug'}

		exit_erron $? "load plugin[%s: %s] with error: $?" "${plugin_labels[i]}" "$hook"

		if [[ $env_file && -f $env_file ]]; then
			eval "$(cat $env_file)"
			local err=$?
			rm -f $env_file
			exit_erron $err "load plugin[%s: %s] variables with error: $err" "${plugin_labels[i]}" "$hook"
		fi
	done
}

function __bad_opt() {
	log_error "$@"
	print_useage
	exit $EX_ERR
}

# parse the options
function __parse_opts() {
	rp=
	config_file=
	branch=
	version=
	git_repo=
	tag_prefix=
	note=
	changelog=
	commit_files=()
	commit_message=
	no_commit_note=
	plugins=()
	deploy="true"
	dry_run=
	no_color_log=
	while [[ $1 ]]; do
		local i=1
		local arg="$1"
		shift
		case "$arg" in
		-c | --config) config_file="$1" ;;
		--rp) rp="$1" ;;
		-b | --branch) branch="$1" ;;
		-v | --version) version="$1" ;;
		-r | --git-repo) git_repo="$1" ;;
		-t | --tag-prefix) tag_prefix="$1" ;;
		--note) note="$1" ;;
		--changelog) changelog="$1" ;;
		-a | --commit) commit_files+=("$1") ;;
		--commit-message) commit_message="$1" ;;
		--no-commit-note) no_commit_note="true" && i=0 ;;
		-p | --plugin)
			plugins+=("$1")
			;;
		--no-deploy) deploy= && i=0 ;;
		-d | --dry-run) dry_run="true" && i=0 ;;
		--debug) DEBUG="true" && i=0 ;;
		--no-color) no_color_log="true" && COLOR_LOG= && i=0 ;;
		-h | --help)
			print_useage
			exit 0
			;;
		-*) __bad_opt "unknown option: $arg" ;;
		*) __bad_opt "unknown command: $arg" ;;
		esac
		for (( ; i > 0; i--)); do
			shift
		done
	done

	# load configuration
	load_config $config_file

	# set default options
	: ${git_repo:="$release_git_repo"}
	: ${tag_prefix:="$release_tag_prefix"}
	: ${changelog:="$release_changelog"}
	: ${note:="$release_release_note"}
	: ${commit_message:="$release_commit_message"}

	commit_note="${release_commit_note}"
	if [[ $no_commit_note ]]; then
		commit_note=
	fi

	if [[ ${#commit_files[@]} -eq 0 ]]; then
		commit_files=("${release_commit_files[@]}")
	fi

	if [[ ${#plugins[@]} -eq 0 ]]; then
		plugins=("${release_plugins[@]}")
	fi

	# parse plugins
	plugin_labels=()
	for ((i = 0; i < ${#plugins[@]}; i++)); do
		plugin_labels+=("${plugins[$i]/ */}")
		plugins[$i]="$(echo ${plugins[$i]} | sed -e "s:^\($(join "\|" "${default_plugins[@]}")\)\($\| \):${plugin_dir//:/\\:}/\1.sh\2:g")"

		exit_erron $? "parse plugin: %s with error: $?" "${plugins[$i]}"
	done

	[[ ! $git_repo ]] && __bad_opt "miss the git repository URL"
	[[ ! $commit_message ]] && __bad_opt "miss the git commit template"

	load_ci

	__load_plugins "load"

	# check branch
	: ${branch:="$(git rev-parse --abbrev-ref HEAD)"}
	if [[ $branch == "HEAD" ]]; then
		branch=$(git show -s --pretty=%d HEAD | awk '{match($0,/origin\/(\w+)/,a);print a[1]}')
	fi
	[[ ! $branch ]] && __bad_opt "miss the release branch"
	[[ ! "$(git rev-parse --verify origin/$branch 2>/dev/null)" ]] &&
		exit_error "the remote branch: <y>origin/$branch</> is not exist"

	# init regexp of tag parser
	#        1                               23          4          5        6 7             8         9 10
	tag_reg="(^${tag_prefix:+"|$tag_prefix"})($num_reg\\.$num_reg\\.$num_reg)(-([a-zA-Z]+)\\.$num_reg)?(@([a-zA-Z]+))?$"
	tag_format_msg="<y>${tag_prefix}{x}.{x}.{x}[-\<prerelease>.{x}][@\<channel>]</>"

	# check version
	if [[ $version ]]; then
		if [[ ! $version =~ $version_reg ]]; then
			local _version=$(echo $version | sed "s:\(^$tag_prefix\|^\):$tag_prefix:")
			if [[ ! $_version =~ $tag_reg ]]; then
				exit_error "invalid version format: <y>%s</>, should be format with $version_format_reg or $tag_format_msg" "$version"
			fi
			version="$_version"
		fi
	fi

	if [[ $deploy ]]; then
		log_info "deploying on branch: <y>$branch</>${dry_run:+" in <y>dry-run</> mode"}"
	else
		log_info "previewing release on branch: <y>$branch</>"
	fi

	log_debug "Options:
  Release Config file           <y>%s</>
  Git Branch name               <y>%s</>
  Git Repository URL            <y>%s</>
  Git Tag Prefix                <y>%s</>
  Release Version               <y>%s</>
  Release Note                  <y>%s</>
  Commit                        <y>%s</>
  Commit Message Template       <y>%s</>
  Commit with Note              <y>${commit_note:-"false"}</>
  Changelog File                <y>%s</>
  Deploy                        <y>${deploy:-"false"}</>
  Dry Run                       <y>${dry_run:-"false"}</>
  Plugins                       <y>%s</>" \
		"$config_file" \
		"$branch" \
		"$git_repo" \
		"$tag_prefix" \
		"${version:-"[auto]"}" \
		"${note:-"[auto]"}" \
		"$(join ", " "${commit_files[@]}")" \
		"$commit_message" \
		"${changelog}" \
		"$(join ", " "${plugin_labels[@]}")"
}

function __load_prev_tag() {
	# load the previous tag
	log_debug "loading the previous release tag on the branch: <y>%s</> ..." "$branch"

	git fetch --prune --prune-tags --tags

	prev_tag="$(git describe --tags --abbrev=0 2>/dev/null)"

	if [[ $prev_tag ]]; then
		log_info "the previous release tag is <y>%s" "$prev_tag"
	else
		log_info "no previous release tag on the branch: <y>%s" "$branch"
	fi
}

function __inc_next_version() {
	local release_type="$1"
	local parts=(0 0 1 0)

	if [[ $prev_tag ]]; then
		log_debug "generating the next release version from %s with <y>%s</> ..." \
			"$prev_tag" \
			"${next_pre:+"pre-"}$release_type"

		if [[ ! $prev_tag =~ $tag_reg ]]; then
			exit_error "can not analyze the next release version from the previous tag: <y>%s</>.
          the git tag should be format with $tag_format_msg" "$prev_tag"
		fi

		parts[0]=${BASH_REMATCH[3]}
		parts[1]=${BASH_REMATCH[4]}
		parts[2]=${BASH_REMATCH[5]}
		local prev_pre="${BASH_REMATCH[8]}"
		parts[3]=${prev_pre:-'0'}

		local inc_part=4
		if [[ ! $release_type ]]; then
			log_info "there are no relevant changes, so no new version is released"
			return $EX_NORELEASE
		fi
		case "$release_type" in
		major) inc_part=0 ;;
		minor) inc_part=1 ;;
		patch) inc_part=2 ;;
		pre)
			[[ ! $next_pre ]] && exit_error "pre-release type: <y>%s</> should be use with pre-release id" "$release_type"
			if [[ $prev_pre ]]; then
				inc_part=3
			else
				inc_part=2
			fi
			;;
		*) exit_error "invalid release type: <y>%s</>" "$release_type" ;;
		esac
		((parts[inc_part++]++))
		for (( ; inc_part < 4; inc_part++)); do
			parts[$inc_part]=0
		done
	fi
	next_version="${parts[0]}.${parts[1]}.${parts[2]}${next_pre:+"-${next_pre}.${parts[3]}"}"
	next_tag="${tag_prefix}${next_version}${next_channel:+"@$next_channel"}"
}

# parse the release version
function __parse_next_version() {
	next_channel=
	if [[ $version =~ $version_reg ]]; then
		next_pre="${BASH_REMATCH[3]}"
		if [[ "${BASH_REMATCH[5]}" != "latest" ]]; then
			next_channel="${BASH_REMATCH[5]}"
		fi
		__inc_next_version "${BASH_REMATCH[1]}"
	else
		[[ ! $version =~ $tag_reg ]] &&
			exit_error "invalid version format: <y>%s</>, should be format with $version_format_reg or $tag_format_msg" "$version"

		next_pre="${BASH_REMATCH[7]}"
		next_version="${BASH_REMATCH[2]}${next_pre:+"-${next_pre}.${BASH_REMATCH[8]}"}"
		if [[ "${BASH_REMATCH[10]}" != "latest" ]]; then
			next_channel="${BASH_REMATCH[10]}"
		fi
		next_tag="${tag_prefix}${next_version}${next_channel:+"@$next_channel"}"
	fi
}

# analyze the release version from commits
function __analyze_next_version() {
	# match branch config
	log_debug "matching release config on the branch: <y>%s</> ..." "$branch"
	local branch_cfg=
	for i in "${release_branchs_[@]}"; do
		local pattern="$(get_var $i pattern)"
		if [[ $branch =~ $pattern ]]; then
			local branch_cfg="$i"
			next_pre="$(get_var $i prerelease)"
			next_channel="$(get_var $i channel)"

			log_debug "matched the release config[<y>/%s/</>], channel: <y>%s</>, pre-release: <y>%s" \
				"$pattern" "${next_channel:-"latest"}" "$next_pre"
			break
		fi
	done

	if [[ ! $branch_cfg ]]; then
		log_info "no release configuration on the branch: <y>%s" "$branch"
		return $EX_NORELEASE
	fi

	# analyzing commits
	log_debug "analyzing commits in <y>%s</>..<y>HEAD</> ..." "$prev_tag"
	local release_type=
	local release_rules=("${release_items[@]}")
	local release_type_field="release"
	if [[ $next_pre ]]; then
		release_rules=("${prerelease_items[@]}")
		release_type_field="prerelease"
	fi
	local commits=($(git log ${prev_tag:+"$prev_tag..HEAD"} --no-merges --pretty=format:"%h" -i -E --grep="$commit_reg"))
	for i in "${commits[@]}"; do
		while read -r line; do
			if [[ ! $line =~ $commit_reg ]]; then
				continue
			fi
			local type="${BASH_REMATCH[1]}"
			local scope="${BASH_REMATCH[3]}"
			local rtype=
			for var in "${release_rules[@]}"; do
				if [[ $type =~ ^$(get_var $var type)$ && $scope =~ ^$(get_var $var scope)$ ]]; then
					rtype="$(get_var $var $release_type_field)"
					break
				fi
			done
			if [[ ! $rtype ]]; then
				log_debug "analyze commit[<y>$i</y>] - skiped at <p>\"%s\"" "$line"
				continue
			fi

			case "$rtype" in
			major) release_type="$rtype" ;;
			minor) release_type="$rtype" ;;
			patch) [[ $release_type != "minor" ]] && release_type="$rtype" ;;
			prerelease) [[ ! $release_type ]] && release_type="$rtype" ;;
			*) exit_error "invalid release type: %s" "$rtype" ;;
			esac

			log_debug "analyze commit[<y>$i</y>] - should release <y>%s</> at <p>\"%s\"" \
				"${next_pre:+"pre-"}$rtype" \
				"$line"

			if [[ $rtype == "major" ]]; then
				break 2
			fi
		done <<<"$(git show -s --format=%B $i)"
	done
	if [[ ! $release_type ]]; then
		log_info "there are no relevant changes, so no new version is released"
		return $EX_NORELEASE
	fi
	__inc_next_version "$release_type"
}

function __release_version() {
	next_parts=
	next_pre=
	next_channel=
	next_version=
	prev_version=
	local err=0

	if [[ $rp ]]; then
		next_tag=
		err=$EX_NORELEASE
		log_info "canceled release on Request Pull(<y>%s</>)" "$rp"
	elif [[ $version ]]; then
		__parse_next_version
	else
		__analyze_next_version
	fi
	err=$?
	__load_plugins "version"
	if [[ $err -eq 0 ]]; then
		[[ "$(git rev-parse --verify $next_tag 2>/dev/null)" ]] &&
			exit_error "the next release tag: <y>%s</y> is existing" "$next_tag"

		log_info "the next release version is <y>%s" "$next_version"
		log_info "the next release tag is <y>%s" "$next_tag"
	fi
	return $err
}

function __generate_release_note() {
	release_note="$note"
	if [[ ! $release_note ]]; then
		# generate release note
		log_debug "generating release note in <y>%s</>..<y>HEAD</> ..." "$prev_tag"

		local note_array=()
		local commits=($(git log ${prev_tag:+"$prev_tag..HEAD"} --no-merges --pretty=format:"%h" -i -E --grep="$commit_reg"))
		for i in "${commits[@]}"; do
			local contents=()
			local notei=
			local body=
			while read -r line; do
				if [[ ! $line =~ $commit_reg ]]; then
					contents+=("$line")
					continue
				fi
				if [[ $notei && $body && ${#contents[@]} -gt 0 ]]; then
					note_array[$notei]+="$(to_str "
  %s" "${contents[@]}")"
				fi
				contents=()

				local type="${BASH_REMATCH[1]}"
				local scope="${BASH_REMATCH[3]}"
				local subject="${BASH_REMATCH[4]}"
				for var in "${note_items[@]}"; do
					if [[ $type =~ ^$(get_var $var type)$ && $scope =~ ^$(get_var $var scope)$ ]]; then
						notei="$(get_var $var notei)"
						body="$(get_var $var body)"
						break
					fi
				done
				if [[ $notei ]]; then
					note_array[$notei]+="
* ${scope:+"$scope: "}$subject ([$i]($git_repo/commit/$i ))"
				fi
			done <<<"$(git show -s --format=%B $i)"

			if [[ $notei && $body && ${#contents[@]} -gt 0 ]]; then
				note_array[$notei]+="$(to_str "
  %s" "${contents[@]}")"
			fi
		done
		release_note="# [$next_version]($git_repo/compare/$prev_tag...$next_tag ) ($(date '+%Y-%m-%d'))
"
		for ((i = 0; i < ${#note_titles[@]}; i++)); do
			if [[ ${note_array[i]} ]]; then
				release_note+="
### ${note_titles[i]}
${note_array[i]}
"
			fi
		done
	fi
	log_debug "Release Note:\n<w>%s" "$release_note"
}

function __generate_changelog() {
	if [[ $changelog ]]; then
		log_info "writing the changelog: <y>%s</> ..." "$changelog"
		if [[ -f $changelog ]]; then
			echo "$release_note
$(cat $changelog)" >$changelog
		else
			echo "$release_note" >$changelog
		fi
		exit_erron $? "write the changelog: <y>%s</> with error: $?" "$changelog"
	fi
}

function __release() {
	if [[ ${#commit_files[@]} -gt 0 ]]; then
		# git commit
		local msg="$(format "$commit_message" \
			tag "$next_tag" \
			version "$next_version" \
			channel "$next_channel" \
			prerelease "$next_pre")"

		log_debug "commiting <y>\"%s\"</> with ${commit_note:+"<y>note</> and "}files: <y>%s" \
			"$msg" \
			"$(join ", " "${commit_files[@]}")"

		git add ${commit_files[@]} --force --ignore-errors
		git_commit "$msg" "${commit_note:+"$release_note"}"

		log_info "commited <y>\"%s\"</> with ${commit_note:+"<y>note</> and "}files: <y>%s" \
			"$msg" \
			"$(join ", " "${commit_files[@]}")"
	fi

	# git tag
	log_debug "creating the git tag: <y>%s</> ..." "$next_tag"

	git tag $next_tag -m "Release $next_tag" -m "$release_note"

	exit_erron $? "create git tag: <y>%s</> with error: $?" "$next_tag"
	log_info "created git tag: <y>%s</>" "$next_tag"

	# git push
	log_debug "pushing <y>%s</> to <y>%s</> ..." "$branch" "$git_repo"

	git_push "$branch" "--follow-tags"

	log_info "pushed <y>%s</> to <y>%s" "$branch" "$git_repo"
}

__parse_opts "$@"
__load_prev_tag
__release_version
err=$?

if [[ $next_tag ]]; then
	__generate_release_note
	if [[ $deploy ]]; then
		__load_plugins "before-deploy"

		git_push "$branch" "--dry-run"

		if [[ ! $dry_run ]]; then
			if [[ $changelog ]]; then
				__generate_changelog
			fi
			__release
			__load_plugins "deploy"
		fi
		log_info "deployed <y>%s</> on branch: <y>%s</>${dry_run:+" in <y>dry-run</> mode"}" "$next_tag" "$branch"
	else
		log_info "will release <y>%s</> on branch: <y>%s" "$next_tag" "$branch"
	fi
else
	if [[ $deploy ]]; then
		log_info "canceled deploy on branch: <y>%s</>${dry_run:+" in <y>dry-run</> mode"}" "$branch"
	else
		log_info "canceled release on branch: <y>%s" "$branch"
	fi
	exit $err
fi
