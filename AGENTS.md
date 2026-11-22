# AGENTS.md — Kryonux Repository Guide

Instructions for AI coding agents (OpenCode, Claude Code and others) working in this repository.

## Project

**Kryonux** is an independent, security-hardened Linux distribution built from scratch on an LFS-style base with `glibc`, `OpenRC`, `Limine` and the custom `kryonk` kernel. Packages are compiled from source by `kpkg`, a standalone package manager written in C.

- **Author and copyright:** The Kryonux Project
- **License:** GNU GPLv3 (`LICENSE`, trademark notice in `NOTICE`)
- **Current version:** `v0.0.1` (website, project, live ISO, `kryonk`). The stage 3 base archive stays at `0.0.0` (`base-0.0.0`). `kpkg` keeps its own version (`2.2.0`, defined in `kpkg/kpkg.c`)
- **Target:** `x86_64`, UEFI and Legacy BIOS, `ext4` and `btrfs`, optional `LUKS2` + `TPM2` and custom `Secure Boot` UKI

## Repositories and paths

- Main repository: `wh1laye/Kryonux`
- Recipes repository: `wh1laye/kpkg-recipes`, kept locally at `/home/wh1laye/kpkg-recipes`; recipes use the `.kpkg` format
- Website domains: `https://wh1laye.github.io/Kryonux/` and `https://kryonux.pages.dev/`

## Layout

| Path | Contents |
| :--- | :--- |
| `kpkg/` | Package manager sources (`*.c`, `kpkg.h`), `Makefile`, `etc/kpkg/`, installer scripts |
| `tools/` | Stage 3, ISO and kernel build scripts, tests (`test-*.sh`, `test-site.js`), forum SQL |
| `tools/kernel/` | `kryonk` config, pin files, overlay, boot and userspace checks |
| `tools/stage3/`, `tools/iso/` | Files installed into stage 3 and the live ISO (`kryonux-install`, `kryonux-firewall`, `kryonux-audit` and others) |
| `docs/` | Static website, Russian pages with English from `docs/i18n.js` and `docs/handbook/en/` |
| `.github/` | CI workflows and templates |

## Commands

- Build kpkg: `make -C kpkg` (compiles with `-Werror`, clean with `make -C kpkg clean`)
- Check the website: `node tools/test-site.js`
- Check JavaScript syntax: `node --check <file>`
- Check shell scripts: `bash -n <file>` and `shellcheck -x <file>` (config in `.shellcheckrc`)
- Stage 3 gate: `bash tools/test-stage3-gate.sh`
- Most other `tools/test-*.sh` scripts need root, a chroot or QEMU; read a script before running it

## Rules

- **Comments:** write zero comments in all source and web files (C, Shell, JS, HTML, CSS, JSON)
- **Naming:** use `Kryonux`, `kryonk`, `kpkg`, `kpkg-recipes` and `.kpkg` consistently. Old names (`Kryounix`, `Cloud*`, `cloudk`, `cloudpkg`, `cloudos`) must not come back
- **Authorship:** use `The Kryonux Project` instead of personal nicknames in copyright, author and license text. GitHub URLs keep the repository path
- **Languages:**
  - CLI output and repository docs (`README.md`, `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`): English
  - Website pages: Russian, with every visible string translated in `docs/i18n.js` (or the page's `I18N_EXTRA`); the handbook also has `docs/handbook/en/`
- **Website visuals:** no emojis and no cloud imagery; use SVG or PNG icons and the logo (`docs/logo.svg`, `docs/logo.png`). Emojis are allowed in `README.md` and other repository docs
- **`docs/config.jsonc`:** keep it in the repository, do not edit it unless asked
- **Sandbox:** the browser sandbox page was removed; do not reintroduce it
- **Sitemap:** keep `docs/sitemap.xml` and `docs/robots.txt` in sync with both website domains when pages are added or removed
- **Service worker:** bump `V` in `docs/sw.js` when cached website assets change
- **Changelog:** record every change in `CHANGELOG.md`, newest version first, grouped by component (website, ISO, stage 3, kryonk, kpkg, repository)
- **kpkg:** read the actual files in `kpkg/` before changing internal logic, flags or filesystem paths. It is source-based and does not use Portage, ebuilds or global `USE` flags
- **Releases:** the stage 3 base tag and `BASE_VERSION` are inputs of the ISO build; do not change them together with a normal version bump
- **Git:** commit and push only when asked

## Release artifacts

- Kernel: `kryonk-0.0.1`
- Live ISO: `kryonux-live-amd64-0.0.1.iso`
- Stage 3 base: `kryonux-stage3-amd64-0.0.0.tar.xz`
- Every artifact has a `.sha256` file and a `minisign` signature checked with `docs/kryonux.pub`
