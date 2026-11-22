# 📝 Changelog

All notable changes to The Kryonux Project are recorded here.

Component versions at this release: Kryonux `v0.0.1`, website `v0.0.1`, live ISO `v0.0.1`, stage 3 `v0.0.1`, kernel `kryonk-0.0.1`, kpkg `0.0.1`.

## [v0.0.1] - 2026-11-22

### 📦 kpkg
#### Added
- `kpkg lint` checks `.kpkg` files for missing fields and syntax errors
- `kpkg install ./name-version.kpkg` installs straight from a local recipe file; dependencies still come from the recipe tree and the package is recorded in the category `local`
- Short build function names in recipes: `prepare`, `configure`, `build`, `install`, `pre_install`, `post_install`, `pre_remove`, `post_remove`. The old `src_*` and `pkg_*` names still work
- `kpkg/RECIPES.md` documents the recipe format

#### Changed
- Version is `0.0.1`; live ISO 0.0.1 is built from stage 3 0.0.1, which is built by kpkg 0.0.1
- `kpkg/README.md` rewritten; kpkg is documented as independent of Gentoo and other package managers

### 🗜️ Stage 3
#### Changed
- Stage 3 is now minimal: the toolchain, core utilities, filesystem tools, `dhcpcd`, `curl`, `openssh`, `nftables`, `nano` and `kpkg`
- Version is `0.0.1`; the builder base is `base-0.0.0` and the ISO consumes the new `base-0.0.1`

#### Removed
- The Gentoo style extra package list, `SOURCES.txt` and its download loop, `fastfetch`, `neofetch`, the logo assets, `make-logo.py`, `tools/pack-fetch.sh` and the `fetch-pack` workflow, and `man-db`, `man-pages`, `psmisc`, `wget`, `rsync`, `git`, `screen`, `autoconf`, `automake` and `libtool` from the package set

#### Fixed
- `build-inside.sh` looked for `kryonux-users` and `kryonux-fix` without the `.sh` suffix, so they were never installed and the archive check failed
- `build-stage3.sh` defaulted to the base release `1.6`

### 🧠 kryonk
#### Changed
- `kryonk` is now a fork of the Linux 6.18 LTS series built from kernel.org sources. Tarballs are verified with the kernel.org PGP signature; the latest 6.18.y release is resolved automatically and can be pinned with `tools/kernel/pin-kernel.sh`
- The fork is the patch series in `tools/kernel/patches/`: `0001-security-add-kryonk-guard.patch` adds `security/kryonk` with `/proc/kryonk` and restrictive defaults (`kptr_restrict=2`, `dmesg_restrict=1`, `panic_on_oops=1`, disabled with `kryonk.guard=0`). Scripted default edits remain in `kryonk-source.sh` and fail the build in strict mode when they do not apply
- Version is `0.0.1`; the target CPU level is passed as `-march` instead of relying on third-party patches

#### Removed
- The CachyOS patch series, key and tag, and the duplicated overlay directories `tools/overlay` and `tools/kernel/overlay`

### 💿 ISO
#### Changed
- Version is `0.0.1` and the default base is the stage 3 `base-0.0.1`

### 🌐 Website
#### Changed
- Every cloud was replaced with the Kryonux logo: the header brand mark on all pages, the pre-login check screen, the summer theme, the space theme background and the forum sticker
- The PWA icons (`icons/icon-192.png`, `icon-512.png`, `icon-maskable-512.png`) were still the old cloud and are now the Kryonux K
- The forum sticker `:s_cloud:` is now `:s_kryonux:`, the cloud emoji was removed from the emoji picker, and the "cloud" color preset is now "cryo"
- Settings were reorganized into four tabs: Theme, Colors, Glass and Reading. Each section has a short hint, the empty "More" tab is gone, and there is a "Reset all settings" button
- Theme stylesheet selectors use `.kryonux`, and the seasonal theme layer class is `zs-logo`
- Handbook, home page, hidden terminal and news show version `v0.0.1`; service worker cache version bumped to `36`

#### Added
- News and RSS entry for `v0.0.1`

### 📚 Repository
#### Added
- `AGENTS.md` with project context for OpenCode and other agents

#### Changed
- Issue templates and the pull request template are in English with sentence case and punctuation
- `CLAUDE.md` rewritten: it imports `AGENTS.md` and keeps the Claude Code specific rules
- `README.md` shows version `v0.0.1` and describes the new stage 3 and kernel

## [v0.0.0] - 2026-11-21

### 🌐 Website
#### Added
- `icon.svg`, `favicon.ico`, `apple-touch-icon.png` and `og.png`, generated from `docs/logo.svg` and `docs/logo.png`; they were referenced by every page and the service worker but missing
- English translations for the footer license line and for all page titles
- `docs/README.md`

#### Changed
- `sitemap.xml` now lists every page for both `https://wh1laye.github.io/Kryonux/` and `https://kryonux.pages.dev/`; `robots.txt` points to both sitemaps
- Page titles follow one `Section: Kryonux` pattern; meta, Open Graph and JSON-LD descriptions share one tagline
- License shown on the site is GNU GPLv3 (stats block, footer, JSON-LD, English handbook); it previously said MIT
- Author shown on the site and in structured data is The Kryonux Project instead of a personal nickname
- Legacy `Cloud*` identifiers renamed: `KryonuxTheme`, `KryonuxSeason`, `KryonuxSecret`, `KryonuxWords`, `KryonuxTypo`, the `kryonuxlang` event, and the `#kryonux` and `.kryonux` selectors
- Service worker cache version bumped to `34`

#### Fixed
- `404.html` loaded its assets from the domain root, which breaks under the `/Kryonux/` project path; it now sets a base path per host
- `og:image` on the hardware and status pages pointed to a root-relative path instead of the absolute URL
- Removed stale i18n entries that mentioned stage 3 `1.6`, live ISO `1.0`, a manual kernel configuration flow and the old MIT and nickname footer strings

#### Removed
- Sandbox page, its navigation entries, its home page card, its command palette entry and its sitemap entry
- "Sandbox" wording in the hidden terminal demo, which now says "demo"

### 💿 ISO and 🗜️ Stage 3
#### Changed
- Leftover `kryounix` name replaced with `kryonux` in all tools, services, paths, environment variables and artifacts: `kryonux-install`, `kryonux-firewall`, `kryonux-audit`, `kryonux-secureboot`, `kryonux-tpm2`, `kryonux-uki`, `KRYONUX_*`, `/etc/kryonux`, `/mnt/kryonux`, `kryonux-live-amd64-0.0.0.iso`, `kryonux-stage3-amd64-0.0.0.tar.xz`
- Release verification key renamed from `kryounix.pub` to `kryonux.pub` (site, `kpkg/etc/kpkg/` and all workflows)
- LUKS mapper name is now `kryonuxcrypt` and the EFI boot partition label is `KRYONUXBOOT`

#### Fixed
- `tools/mkiso.sh` and the CI workflows looked for `kryounix-stage3-*` while `tools/build-stage3.sh` produced `kryonux-stage3-*`, so the ISO build could not find its base archive

### 🧠 kryonk
#### Changed
- `MODULE_AUTHOR` is now The Kryonux Project

### 📦 kpkg
#### Changed
- Documentation rewritten in English with the current command list

### 📚 Repository
#### Added
- English `README.md` with logo, ASCII art, component table and quick start
- `CHANGELOG.md`

#### Changed
- `tools/README.md` and `kpkg/README.md` translated to English; `tools/README.md` no longer claims the MIT license
- `CLAUDE.md` updated with the changelog rule and the current conventions
