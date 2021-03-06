# General Release

[![Appveyor][appveyor-badge]][appveyor]
[![Travis][travis-badge]][travis]
[![Version][version-badge]][npm]
[![Downloads][downloads-badge]][npm]

Automatic Release Tool for Git repository using bash shell

## Features

- [x] Release version
  - [x] Analyze the release/pre-release version from the commits after the last git-tag
  - [x] Specifies the release/pre-release version number
  - [x] Increment the release/pre-release version at the specified level based on the last git-tag
- [x] Generate release note
  - [x] Generate the release note from the commits after the last git-tag
- [x] Generate changelog
- [x] Git commit, tag, push
- [x] CI support
  - [x] Appveyor
  - [x] Travis
  - [x] CircleCI
  - [x] GitlabCI
  - [x] Jenkins
- [x] Archive files (use gzip plugin)
- [x] Create release at GitHub (use github plugin)
- [x] Create release at NPM (use npm plugin)
- [ ] Create release at Yum (use yum plugin)
- [ ] Create release at Maven (use maven plugin)
- [x] Update appveyor build details (use appveyor plugin)
- [x] Custom plugin
- [x] Validate the commit message
- [x] Tools: commit template and commit linter

## Dependencies

- Bash Shell
- Git (`>=1.17.0`)

## Commit Message Format

Each commit message consists of one or more headers and bodies. The header has a special format that includes a type, a scope and a subject:

```text
<type>(<scope>): <subject>
<body>

<type>(<scope>): <subject>
<body>
```

The header is mandatory and the scope of the header is optional.

## Release Rule Configuration (yml)

- The Config Fields

Field Name                                     | Field Type | Description
-----------------------------------------------|------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
`tag_repo`                                     | string     | Git repository URL, default: `[auto]` <br> Get the url with command: `git config --get remote.origin.url`
`tag_prefix`                                   | string     | Prefix of the Git tag , default: `v`
`release_note`                                 | string     | Release Note, default: `[auto]` <br> Analyze the commits after the last Git tag by the rules defined in the configuration
`changelog`                                    | string     | Generante the changelog file, default: `CHANGELOG.md`
`commit`                                       | string[]   | Git commit files, default: `CHANGELOG.md`
`commit_message`                               | string     | Commit message template, default: `chore(release): {tag} [skip ci]`, the format variables: <br> - `version`: Release version <br> - `channel`: Release channel <br> - `prerelease`: Pre-release id <br> - `tag`: Release Git tag
`commit_note`                                  | boolean    | Commit with release note, default: `true`
`plugins`                                      | string[]   | Plugins <br> - `github [--file, --token] [options]` <br> - `npm [--registry, --access, --token] [options]` <br> - `appveyor [options]` <br> - `constum.sh [options]`
**branchs**                                    | object[]   | The branch config
&nbsp;&nbsp;&nbsp;&nbsp;`branchs[].pattern`    | regexp     | `required`: Pattern of the release branch name
&nbsp;&nbsp;&nbsp;&nbsp;`branchs[].channel`    | string     | Publish channel
&nbsp;&nbsp;&nbsp;&nbsp;`branchs[].prerelease` | string     | Pre-release id
**rules**                                      | object[]   | Rules for release version analyzer and release note generator
&nbsp;&nbsp;&nbsp;&nbsp;`rules[].type`         | regexp     | `required`: Pattern of the commit type
&nbsp;&nbsp;&nbsp;&nbsp;`rules[].scope`        | regexp     | Pattern of the commit scope
&nbsp;&nbsp;&nbsp;&nbsp;`rules[].release`      | string     | The Release type:`major`, `minor`, `patch`, `none`, default `none`
&nbsp;&nbsp;&nbsp;&nbsp;`rules[].prerelease`   | string     | The Pre-release type: `major`, `minor`, `patch`, `prerelease`, `none`, default: `prerelease`
&nbsp;&nbsp;&nbsp;&nbsp;`rules[].note`         | string     | Title of the release note
&nbsp;&nbsp;&nbsp;&nbsp;`rules[].body`         | boolean    | Include the commit body to release note

- general-release looks the config file at `.release.yml`
- Use `--config` or `-c` to use another path
- The default configuration: [release.yml](src/release.yml)

## Usage

### Shell

- Download general-release
  ```bash
  # download
  curl -L -s https://github.com/billowz/general-release/releases/download/$(curl -L -s -H 'Accept: application/json' https://github.com/billowz/general-release/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')/general-release.zip -o general-release.zip
  unzip -o general-release.zip -d general-release
  rm -f general-release.zip
  ```

- Release

  ```bash
  # deploy with github plugin
  general-release/bin/bin.sh -c .release.yml -p "github -f release.zip" --debug
  # or
  general-release/bin/bin.sh deploy -c .release.yml -p "github -f release.zip" --debug

  # dry-run mode
  general-release/bin/bin.sh -c .release.yml -p "github -f release.zip" --debug --dry-run
  ```

- Preview Release

  ```bash
  general-release/bin/bin.sh preview -c .release.yml --debug
  # or
  general-release/bin/bin.sh --no-deploy -c .release.yml --debug
  ```

- Release with the specialed version

  ```bash
  # release with specified version: 1.0.0
  general-release/bin/bin.sh -v 1.0.0

  # release with specified version on the specified channel
  general-release/bin/bin.sh -v 1.0.0@next

  # release with specified pre-release version
  general-release/bin/bin.sh -v 1.0.0-alpha

  # release with specified pre-release version on the specified channel
  general-release/bin/bin.sh -v 1.0.0-alpha@next

  # increment the version by the specified level from the last git-tag
  general-release/bin/bin.sh -v minor

  # increment the version by the specified level on the specified channel from the last git-tag
  general-release/bin/bin.sh -v minor@next

  # increment the pre-release version by the specified level from the last git-tag
  general-release/bin/bin.sh -v pre-alpha

  # increment the pre-release version by the specified level on the specified channel from the last git-tag
  general-release/bin/bin.sh -v pre-alpha@next
  ```

- Validate the commit message

  ```bash
  general-release/bin/bin.sh validate -c .release.yml "feat: test"
  ```

- Install the Tools: commit-linter, commit-template

  ```bash
  # install commit template and commit linter
  general-release/bin/bin.sh install -c .release.yml
  # of
  general-release/bin/bin.sh install -c .release.yml --commit-lint --commit-template

  # install commit template
  general-release/bin/bin.sh install -c .release.yml --commit-template

  # install commit template on the specified file
  general-release/bin/bin.sh install -c .release.yml --template ./commit-template
  ```

- Uninstall the Tools: commit-linter, commit-template

  ```bash
  # uninstall commit template and commit linter
  general-release/bin/bin.sh uninstall
  # of
  general-release/bin/bin.sh uninstall --commit-lint --commit-template

  # uninstall commit template
  general-release/bin/bin.sh uninstall --commit-template
  ```

- Print Usage

  ```bash
  general-release/bin/bin.sh -h
  general-release/bin/bin.sh deploy -h
  general-release/bin/bin.sh preview -h
  general-release/bin/bin.sh validate -h
  general-release/bin/bin.sh install -h
  general-release/bin/bin.sh uninstall -h
  ```

### NodeJS

- Set the default options in package.json with `releaseConfig` property

Property                       | Property Type             | Description
-------------------------------|---------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
`releaseConfig.config`         | string                    | The config file, default: `.release.yml` or [node_modules/general-release/src/release.yml](src/release.yml)
`releaseConfig.commitTemplate` | string                    | The path of generated commit template file, default: `.gitmessage`
`releaseConfig.tools`          | boolean, string, string[] | Auto install/uninstall the tools: `commit-template`, `commit-lint`, default: `true` <br> - `true`: Install/Uninstall all tools on install/uninstall `general-release` <br> - `false`: Not install/uninstall any tools on install/uninstall `general-release` <br> - `string`, `string[]`: Install/Uninstall the specified tools on install/uninstall `general-release`

  - e.g.

  ```json
  {
    "releaseConfig": {
      "config": "config/release.yml",
      "commitTemplate": "config/commit_template",
      "tools": true
    }
  }
  ```

- Install general-release

  ```bash
  npm install -g general-release
  # or
  npm install -D general-release
  ```

- Release

  ```bash
  # deploy with github and npm plugin
  npx general-release -c .release.yml -p "github -f release.zip" -p npm --debug
  # or
  npx general-release deploy -c .release.yml -p "github -f release.zip" -p npm --debug

  # dry-run mode
  npx general-release -c .release.yml -p "github -f release.zip" -p npm --debug --dry-run
  ```

- Preview Release

  ```bash
  npx general-release preview -c .release.yml --debug
  # or
  npx general-release --no-deploy -c .release.yml --debug
  ```

- Release with the specialed version

  ```bash
  # release with specified version: 1.0.0
  npx general-release -v 1.0.0

  # release with specified version on the specified channel
  npx general-release -v 1.0.0@next

  # release with specified pre-release version
  npx general-release -v 1.0.0-alpha

  # release with specified pre-release version on the specified channel
  npx general-release -v 1.0.0-alpha@next

  # increment the version by the specified level from the last git-tag
  npx general-release -v minor

  # increment the version by the specified level on the specified channel from the last git-tag
  npx general-release -v minor@next

  # increment the pre-release version by the specified level from the last git-tag
  npx general-release -v pre-alpha

  # increment the pre-release version by the specified level on the specified channel from the last git-tag
  npx general-release -v pre-alpha@next
  ```

- Validate the commit message

  ```bash
  npx general-release validate -c .release.yml "feat: test"
  ```

- Install the Tools: commit-linter, commit-template

  ```bash
  # install commit template and commit linter
  npx general-release install -c .release.yml
  # of
  npx general-release install -c .release.yml --commit-lint --commit-template

  # install commit template
  npx general-release install -c .release.yml --commit-template

  # install commit template on the specified file
  npx general-release install -c .release.yml --template ./commit-template
  ```

- Uninstall the Tools: commit-linter, commit-template

  ```bash
  # uninstall commit template and commit linter
  npx general-release uninstall
  # of
  npx general-release uninstall --commit-lint --commit-template

  # uninstall commit template
  npx general-release uninstall --commit-template
  ```

- Print Usage

  ```bash
  npx general-release -h
  npx general-release deploy -h
  npx general-release preview -h
  npx general-release validate -h
  npx general-release install -h
  npx general-release uninstall -h
  ```

## Plugin API

- Usage

  ```bash
  general-release/bin/bin.sh -p "github -f general-release.zip --debug" -p "npm --debug" -p "coustom.sh --debug"
  ```

- _`./src/plugin.sh`_
  - Methods

Name                | Type                                                | Description
--------------------|-----------------------------------------------------|---------------------------------------
`bootstrap`         | `function(...)`                                     | Running the plugin, `bootstrap "$@"`
`plugin_state`      | `function()`                                        | Print running state of the plugin
`print_usage`       | `function()`                                        | Print usage
`plugin_debug`      | `function(msg, ...)`                                | Print debug
`plugin_info`       | `function(msg, ...)`                                | Print info
`plugin_warn`       | `function(msg, ...)`                                | Print warn
`plugin_error`      | `function(msg, ...)`                                | Print error
`plugin_exit_error` | `function(int exit_code?, msg, ...)`                | Exit and print error
`plugin_exit_erron` | `function(int condition?,int exit_code?, msg, ...)` | Exit and print error on condition != 0


  - Extensions

Name             | Type                            | Description
-----------------|---------------------------------|-----------------------------------------------------------
`plugin_name`    | `string`                        | The plugin name
`plugin_arg`     | `function(opt_name, opt_value)` | Option parser of the plugin
`plugin_init`    | `function(hook)`                | Initial callback of the plugin, called before execute hook
`plugin_{hook}`  | `string`                        | Command of the plugin hook
`plugin_usage`   | `function()`                    | Print usage message
`plugin_options` | `function()`                    | Print plugin options

  - Plugin Context


Name           | Type      | Description
---------------|-----------|------------------------------------------------------------
`hook`         | string    | The plugin hook
`env_file`     | file path | Output the release variables(`branch`, `rp`) on `load` hook
`git_repo`     | string    | Git repository url
`branch`       | string    | Branch name
`tag_prefix`   | string    | Prefix of the git-tag
`prev_tag`     | string    | The last release git-tag
`tag`          | string    | Release git-tag
`version`      | string    | Release version
`channel`      | string    | Release channel
`prerelease`   | string    | Pre-release id
`release_note` | string    | Release note
`dry_run`      | "true"    | Is dry run
`DEBUG`        | "true"    | Is debug mode
`COLOR_LOG`    | "true"    | Is color log mode

### Plugin Hooks

Hook Name       | Description
----------------|--------------------------------------------------------------------------------
`load`          | On release loading, output the release variables(`branch`, `rp`) to `$env_file`
`version`       | Called after release version analyzed
`before_deploy` | Called before deploy
`deploy`        | Called on deploy
`after-deploy`  | Called after deploy
`deploy-failed` | Called after deploy

### How to write a custom plugin ?

```shell
#!/bin/bash

# include plugin libary
source $(dirname $BASH_SOURCE)/../lib/plugin.sh

# the plugin name
plugin_name="plugin name"

# command of the plugin hooks

plugin_load="hook_load"
plugin_version="hook_version"
plugin_before_deploy="print_state && hook_before_deploy"
plugin_deploy="hook_deploy"

# the option parser

test_option1=
test_option2=
function plugin_arg() {
	case "$1" in
	--test1)
		test_option1="$2"
		# eat 2 argument
		return 2
		;;
	--test)
		test_option2="true"
		# eat 1 argument
		return 1
		;;
	esac
	# unkown option
	return 0
}

# print the options
function plugin_options(){
  color_log "<g>  --test1                       [string] Test string option
  --test2                       [enable] Test enable option"
}

# print the plugin state
function print_state() {
	plugin_debug "Options:<g>
  test_option1                  <y>%s</>
  test_option2                  <y>%s</>" \
		"$test_option1" \
		"$test_option2"
	plugin_state
}

# initial plugin before execute hook
function plugin_init(){
	# do something ...
}

# example hook[load]
function hook_load() {
	# do something ...

	# out variables
	echo "rp=" > $env_file
}

# example hook[version]
function hook_version() {
	if [[ $version ]]; fi
		plugin_debug "the release version is $version"
	else
		plugin_debug "no release version"
	fi
	# do something ...
}

# example hook[before-deploy]
function hook_before_deploy() {
	if [[ ! $dry_run ]]; then
		# do something ...
	else
		# do something ...
	fi
}

# example hook[deploy]
function hook_deploy() {
	if [[ ! $dry_run ]]; then
		# do something ...
	else
		# do something ...
	fi
}

# bootstrap the plugin
bootstrap "$@"
```

## Plugins

### Gzip Plugin

Archive files by tar

- Usage

  ```text
  Usage
    gzip [<options>] [<path>...]
  Plugin Options
    -o,--output                   [string] Write the archive to this file(.tar.gz)
    -d,--dry-run                  [enable] Skip publishing, default: false
    --debug                       [enable] Enable debug logging, default: false
    --no-color                    [enable] Disable the color output, default: false
    -h,--help                     Print usage
  ```

### NPM Plugin

Publish a npm package

- Usage

  ```text
  Usage
    npm [<options>]
  Plugin Options
    -r,--registry                 [string] NPM registry URL, default: https://registry.npmjs.org/
    -a,--access                   [string] Package access, default: public
    -t,--token                    [string] NPM auth token, default: ENV:NPM_TOKEN
    -d,--dry-run                  [enable] Skip publishing, default: false
    --debug                       [enable] Enable debug logging, default: false
    --no-color                    [enable] Disable the color output, default: false
    -h,--help                     Print usage
  ```

### GitHub Plugin

Create a release at gitHub

- Usage

  ```text
  Usage
    github [<options>]
  Plugin Options
    -f,--file                     [string] Add a publish file
    -t,--token                    [string] GitHub auth token, default: ENV:GITHUB_TOKEN
    -d,--dry-run                  [enable] Skip publishing, default: false
    --debug                       [enable] Enable debug logging, default: false
    --no-color                    [enable] Disable the color output, default: false
    -h,--help                     Print usage
  ```

### Appveyor Plugin

Write Build Details on Appveyor

- Usage

  ```text
  Usage
    appveyor [<options>]
  Plugin Options
    -d,--dry-run                  [enable] Skip publishing, default: false
    --debug                       [enable] Enable debug logging, default: false
    --no-color                    [enable] Disable the color output, default: false
    -h,--help                     Print usage
  ```

## License

[MIT](http://opensource.org/licenses/MIT)

[appveyor]: https://ci.appveyor.com/project/billowz/general-release/branch/master
[appveyor-badge]: https://img.shields.io/appveyor/ci/billowz/general-release/master.svg
[travis]: https://travis-ci.org/billowz/general-release
[travis-badge]: https://img.shields.io/travis/billowz/general-release/master.svg
[npm]: https://www.npmjs.com/package/general-release/v/latest
[downloads-badge]: https://img.shields.io/npm/dt/general-release.svg
[version-badge]: https://img.shields.io/npm/v/general-release/latest.svg
