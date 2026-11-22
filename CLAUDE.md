# CLAUDE.md

@AGENTS.md

## Claude Code notes

- `AGENTS.md` is the single source of project context and rules; update it instead of duplicating rules here
- Read the real files before editing: names, paths and flags in `kpkg/` and `tools/` change often
- After editing website files run `node tools/test-site.js` and `node --check` on every changed `.js` file
- After editing `kpkg/` run `make -C kpkg` and remove the build output
- After editing shell scripts run `bash -n` and `shellcheck -x`
- Add a `CHANGELOG.md` entry for every change before finishing
