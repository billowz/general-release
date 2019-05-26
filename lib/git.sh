#!/bin/bash

source $(dirname $BASH_SOURCE)/util.sh

EX_DIRTYHEAD=2

[[ ! -x "$(command -v git)" ]] && exit_error "you need to install the git"
[[ ! "$(git rev-parse --git-dir)" ]] && exit_error "not running from a git repository."

function git_commit() {
	local msg="$1"
	local note="$2"
	if [[ $note ]]; then
		git commit -m "$msg" -m "$note"
	else
		git commit -m "$msg"
	fi
	exit_erron $? "git commit <y>\"%s\"</> with error: $?" "$msg"
}

# git_push(<branch>, options...)
function git_push() {
	local branch="$1"
	shift

	# check auth
	local username=$(git config --get user.name)
	local email=$(git config --get user.email)
	if [[ ! $username || ! $email ]]; then
		git config --local user.name "Release"
		git config --local user.email "tao.zeng.zt@qq.com"
	fi
	log_debug "git push %s origin HEAD:%s with %s\<%s>" \
		"$@" "$branch" \
		"$(git config --get user.name)" \
		"$(git config --get user.email)"

	local out="$(git push $@ origin HEAD:$branch 2>&1)"
	local err=$?
	if [[ $err -ne 0 ]]; then
		local head="$(git rev-parse HEAD)"
		local remote_head="$(git ls-remote --heads origin $branch | awk "{print \$1}")"
		git merge-base --is-ancestor $remote_head $head
		[[ ! $? ]] &&
			exit_code $EX_DIRTYHEAD \
				log_warn "the local branch: <y>%s</> is behind the remote one" "$branch"
		exit_error $err "git push with error: $err\n%s" "$out"
	fi
}