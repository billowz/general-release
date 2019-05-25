#!/usr/bin/env node

const path = require("path");
const shell = require("shelljs");

const nodeModulesReg = /[/\\]node_modules[/\\].*/,
	cwd = process.cwd(),
	inNodeModules = nodeModulesReg.test(cwd),
	root = cwd.replace(nodeModulesReg, ""),
	pkg = require(path.join(root, "./package.json")),
	cfg = pkg.releaseConfig || {},
	args = process.argv.slice(2),
	cmd = args[0] || "",
	optIdx = /^-/.test(cmd) ? 0 : 1;

if (/^(install|uninstall)$/.test(cmd)) {
	if (inNodeModules) {
		if (cfg.tools === false) return;
		if (cfg.tools && typeof cfg.tools === "string") {
			args.splice(optIdx, 0, `--${cfg.tools}`);
		} else if (Array.isArray(cfg.tools)) {
			cfg.tools.forEach(t => args.splice(optIdx, 0, `--${t}`));
		}
	}
	if (cmd === "install" && cfg.commitTemplate) {
		args.splice(optIdx, 0, "--template", cfg.commitTemplate);
	}
}

if (cmd !== "uninstall" && cfg.config) {
	args.splice(optIdx, 0, "--config", cfg.config);
}

shell.exit(
	shell.exec(
		`cd "${root}" && sh ${path.join(__dirname, "bin.sh")} ${args
			.map(arg => `'${arg}'`)
			.join(" ")}`
	).code
);
