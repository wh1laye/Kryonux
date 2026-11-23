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
- `kpkg checksum file.kpkg` downloads every source and writes the `SHA256` field
- Recipe versions may contain lowercase letters, such as `9.9p1`
- `SHA256` recipe field: every downloaded source is verified and `kpkg lint` requires it

#### Fixed
- Installing from a local `.kpkg` file crashed with a buffer overflow detected by the new tests; the path buffer is now `PATH_MAX`
- `kpkg lint` rejected valid recipes that rely on the default build steps

#### Changed
- The Gentoo style `Manifest` checks (BLAKE2B and SHA512) were replaced by the `SHA256` field
- Recipe header keys may contain digits, so `SHA256` is a valid key
- Version is `0.0.1`; live ISO 0.0.1 is built from stage 3 0.0.1, which is built by kpkg 0.0.1
- `kpkg/README.md` rewritten; kpkg is documented as independent of Gentoo and other package managers

### 🗜️ Stage 3
#### Changed
- Stage 3 is now minimal: the toolchain, core utilities, filesystem tools, `dhcpcd`, `curl`, `openssh`, `nftables`, `nano`, `fastfetch` and `kpkg`, plus the build tools `m4`, `autoconf`, `automake`, `libtool`, `bison`, `flex`, `pkgconf`, `gmp`, `mpfr` and `mpc`, and the base tools every system needs: `openrc`, `limine`, `kmod`, `eudev`, `ncurses`, `readline`, `less`, `file`, `iproute2`, `iputils` and `minisign`
- Version is `0.0.1`; the builder base is `base-0.0.0` and the ISO consumes the new `base-0.0.1`

#### Removed
- The Gentoo style extra package list, `SOURCES.txt` and its download loop, `neofetch`, the old logo assets, `make-logo.py`, `tools/pack-fetch.sh` and the `fetch-pack` workflow, and `man-db`, `man-pages`, `psmisc`, `wget`, `rsync`, `git`, `screen`, `autoconf`, `automake` and `libtool` from the package set

#### Added
- `fastfetch` with the Kryonux K logo: the configuration moved from `docs/config.jsonc` to `tools/stage3/fastfetch.jsonc` and is installed as `/etc/xdg/fastfetch/config.jsonc`

#### Fixed
- `build-inside.sh` looked for `kryonux-users` and `kryonux-fix` without the `.sh` suffix, so they were never installed and the archive check failed
- `build-stage3.sh` defaulted to the base release `1.6`

### 🧪 Tests
#### Added
- `tools/test-iso.sh` with 67 checks: the files `mkiso.sh` needs exist, scripts parse, versions match `kpkg` everywhere, artifact names agree, the kernel builds in the live system filesystems, the live init and installer have what they need, the stage 3 list covers the ISO tools, and no foreign names remain. It runs in CI
- kpkg tests grew from 13 to 31: recipe linting, installing from a local `.kpkg` file, `kpkg checksum` and SHA256 mismatch handling
- `tools/test-recipes.sh` in the recipes repository

#### Fixed
- CI failed to compile `kpkg/cmds.c` with `-Werror=format-truncation`; the local recipe path buffer is now `PATH_MAX` long

### 🧠 kryonk
#### Changed
- `kryonk` is now a fork of the Linux 6.18 LTS series built from kernel.org sources. Tarballs are verified with the kernel.org PGP signature; the latest 6.18.y release is resolved automatically and can be pinned with `tools/kernel/pin-kernel.sh`
- The fork is the patch series in `tools/kernel/patches/`: `0001-security-add-kryonk-guard.patch` adds `security/kryonk` with `/proc/kryonk` and restrictive defaults (`kptr_restrict=2`, `dmesg_restrict=1`, `panic_on_oops=1`, disabled with `kryonk.guard=0`). Scripted default edits remain in `kryonk-source.sh` and fail the build in strict mode when they do not apply
- Version is `0.0.1`; the target CPU level is passed as `-march` instead of relying on third-party patches

#### Added
- Patches `0002` and `0003`: the one-way `kernel.kryonk.lock` sysctl and the lock state in `/proc/kryonk`
- More hardening in `kryonk.config`: Landlock, no `kexec`, hibernation, `/proc/kcore`, `TIOCSTI` and `modify_ldt`, strict `/dev/mem` and zeroed call-used registers
- `tools/kernel/README.md` documents the patch series, build variables and signing

#### Fixed
- The CI run `kryonk #2` failed late in the build. Patch 0002 referenced `modules_disabled`, which the 6.18 kernel no longer exports, so the final link failed. The patch no longer touches it, and `ZERO_CALL_USED_REGS` was removed from `kryonk.config`. A failed parallel build is now repeated with one job so the real compiler error is printed
- The CI run `kryonk #1` built the kernel but failed with "Error while loading the secret key file". The workflow passes the key as a file path while `tools/sign.sh` treated the variable as the key text. `sign.sh` now accepts a file path or the key text, rejects anything that is not a minisign key, and signs keys without a password with `-W`

#### Removed
- The CachyOS patch series, key and tag, and the duplicated overlay directories `tools/overlay` and `tools/kernel/overlay`

### 💿 ISO
#### Changed
- Version is `0.0.1` and the default base is the stage 3 `base-0.0.1`

### 🌐 Website
#### Changed
- Every cloud was replaced with the Kryonux logo: the header brand mark on all pages, the pre-login check screen, the summer theme, the space theme background and the forum sticker
- The PWA icons (`icons/icon-192.png`, `icon-512.png`, `icon-maskable-512.png`) were still the old cloud and are now the Kryonux K
- The summer theme flies redesigned fluffy clouds with a soft shadow, and the space theme drops meteorites and comets diagonally down the screen in separate lanes so they no longer overlap or fly sideways. The purple K over the header in the space theme is gone: the seasonal brand overlays no longer redraw the logo shape; the Kryonux logo no longer drifts across the themes. Logo icons stay in the header, the pre-login screen and the forum sticker
- The forum sticker `:s_cloud:` is now `:s_kryonux:`, the cloud emoji was removed from the emoji picker, and the "cloud" color preset is now "cryo"
- The header logo is a tight crop of the K and sits next to `ryonux` like a letter; `canonical` links were added to every page and `theme-color` to the 404 and offline pages
- Settings have five tabs: Theme, Colors, Glass, Reading and More. The More tab with all extra options (view and comfort, text, appearance, extras) is kept. Each core section has a short hint, and there is a "Reset all settings" button
- Brand text: `typo.js` capitalized the first letter of the header text, so `ryonux` rendered as `Ryonux`; the header brand is now excluded
- Stronger ice and diamond look: frosted gradient cards with a light sweep on hover, ice chips, a second diamond facet in the hero and a deep blue dark theme
- New ice and diamond look: icy blue light and dark palettes, a faint crystal lattice background, a diamond facet behind the home hero and gradient accent buttons
- In the header the Kryonux logo now replaces the letter K, so the brand reads as the logo followed by `ryonux`
- Theme stylesheet selectors use `.kryonux`, and the seasonal theme layer class is `zs-logo`
- Handbook, home page, hidden terminal and news show version `v0.0.1`; service worker cache version bumped to `41`

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
