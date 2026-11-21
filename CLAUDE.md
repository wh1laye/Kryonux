# CLAUDE.md — Kryonux Repository Context

## Project Overview

**Kryonux** is an independent, security-hardened Linux distribution built from scratch on an LFS-style base using `glibc`, `OpenRC`, `Limine`, and the custom `kryonk` kernel. Packages are compiled from source with the custom C-based package manager `kpkg`.

- **Author & Copyright:** The Kryonux Project
- **License:** GNU GPLv3
- **Current Version:** `v0.0.0`
- **Target Architecture:** `x86_64` (UEFI and Legacy BIOS, `ext4` and `btrfs`, optional `LUKS2` + `TPM2` and custom `Secure Boot` UKI)

## Package Manager (`kpkg`)

- **Design:** Standalone source-based package manager written in C. It does not use Gentoo Portage, ebuilds, or global `USE` flags; build options are defined per recipe inside `.kpkg` files.
- **Local Recipe Repository:** `/home/wh1laye/kpkg-recipes`
- **Features:** Dependency resolution, `minisign` signature verification for sources, automatic `btrfs` snapshots before upgrades (`kpkg upgrade` / `kpkg rollback`), and environment diagnostics (`kpkg doctor` / `kpkg fix`).
- **Source Inspection:** Always read the actual files inside the `kpkg/` directory before modifying internal logic, flags, or filesystem paths.

## System Build Pipeline

- **Stage 3:** Base rootfs archive built with `kpkg` inside a chroot environment.
- **Live ISO:** Bootable image containing the `kryonk` kernel, `squashfs` rootfs, and `Limine` bootloader for UEFI and BIOS.
- **Kernel (`kryonk`):** Built from upstream Linux sources with signature verification, KSPP hardening options, and built-in disk/filesystem drivers (boots without `initramfs` unless `LUKS2` is used).

## Release Artifacts

- **Kernel:** `kryonk-0.0.0`
- **Stage 3:** `kryonux-stage3-amd64-0.0.0.tar.xz`
- **Live ISO:** `kryonux-live-amd64-0.0.0.iso`

## Conventions & Style

- **Code:** Write zero comments in all source and web files (C, Shell, JS, HTML, CSS, JSON).
- **Naming:** Use `Kryonux`, `kryonk`, `kpkg`, `kpkg-recipes`, and `.kpkg` consistently across the repository.
- **Languages:**
  - CLI output and repository docs (`README.md`, `CHANGELOG.md`): English only.
  - Website (`docs/`): Russian and English synchronized via `docs/i18n.js`.
- **Website Assets:** No emojis on the website; use SVG/PNG icons, `docs/logo.png`, `docs/logo.svg`, and ASCII art from `docs/config.jsonc` (keep `docs/config.jsonc` in the repo). Emojis are allowed in `README.md`.
- **Website Domains:** `https://wh1laye.github.io/Kryonux/` and `https://kryonux.pages.dev/`; keep `docs/sitemap.xml` and `docs/robots.txt` in sync with both.
- **Changelog:** Record every change in `CHANGELOG.md`, grouped by component and version (`v0.0.0` for the website, ISO, stage 3, kernel and project; kpkg keeps its own version).
- **Authorship:** Use `The Kryonux Project` instead of personal nicknames in copyright, author and license text. GitHub URLs keep the repository path.
- **Removed:** The browser sandbox page no longer exists; do not reintroduce it.
