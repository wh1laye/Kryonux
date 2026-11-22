<div align="center">

<img src="docs/logo.svg" alt="Kryonux logo" width="120" height="120">

# 💎 Kryonux

**A fast, security-hardened Linux distribution built on an LFS-style base.**

![version](https://img.shields.io/badge/version-v0.0.1-5fb4ff?style=flat-square)
![license](https://img.shields.io/badge/license-GPLv3-blue?style=flat-square)
![arch](https://img.shields.io/badge/arch-x86__64-informational?style=flat-square)
![init](https://img.shields.io/badge/init-OpenRC-success?style=flat-square)

[🌐 Website](https://wh1laye.github.io/Kryonux/) · [📖 Handbook](https://wh1laye.github.io/Kryonux/handbook/en/) · [📦 Releases](https://github.com/wh1laye/Kryonux/releases) · [🍳 Recipes](https://github.com/wh1laye/kpkg-recipes) · [💬 Forum](https://wh1laye.github.io/Kryonux/forum/)

</div>

---

## ✨ Overview

Kryonux is an independent Linux distribution built from scratch on an LFS-style base with `glibc`, `OpenRC`, `Limine` and its own kernel, `kryonk`. Every package is compiled from source by `kpkg`, a standalone package manager written in C.

| Component | What it is | Version |
| :--- | :--- | :--- |
| 🐧 **Kryonux** | The distribution | `v0.0.1` |
| 🧠 **kryonk** | Hardened kernel built from kernel.org sources | `kryonk-0.0.1` |
| 📦 **kpkg** | Source-based package manager written in C | `2.2.0` |
| 🍳 **kpkg-recipes** | Package recipes in `.kpkg` format | [separate repository](https://github.com/wh1laye/kpkg-recipes) |
| 🗜️ **Stage 3** | Base root filesystem archive | `kryonux-stage3-amd64-0.0.0.tar.xz` |
| 💿 **Live ISO** | Bootable installer image | `kryonux-live-amd64-0.0.1.iso` |

## 🛡️ Highlights

- 🔒 **Hardened kernel**: `kryonk` is built from upstream sources with signature verification, KSPP options and built-in disk and filesystem drivers, so it boots without an initramfs unless LUKS2 is used
- 🧱 **Restrictive defaults**: nftables with `drop` policies, sysctl hardening, limited logins and an unprivileged user with `doas`
- 🔐 **Full-disk encryption**: optional `LUKS2` with `TPM2` unlock and custom `Secure Boot` UKI images
- 🖥️ **UEFI and Legacy BIOS** with `ext4` or `btrfs`, booted by `Limine`
- 🗂️ **No systemd, no Portage**: `OpenRC` services and per-recipe build options instead of global `USE` flags
- ♻️ **Safe upgrades**: automatic `btrfs` snapshots before `kpkg upgrade` and one-command `kpkg rollback`
- ✍️ **Signed releases**: artifacts are verified with `minisign` using `docs/kryonux.pub`

## 🚀 Quick start

1. Download `kryonux-live-amd64-0.0.1.iso` and its `.sha256` and `.minisig` files from [Releases](https://github.com/wh1laye/Kryonux/releases).
2. Verify the image:

```sh
sha256sum -c kryonux-live-amd64-0.0.1.iso.sha256
minisign -V -p docs/kryonux.pub -m kryonux-live-amd64-0.0.1.iso
```

3. Boot the ISO and run the installer:

```sh
doas kryonux-install
```

The [handbook](https://wh1laye.github.io/Kryonux/handbook/en/) also covers manual installation step by step.

## 📦 kpkg

```sh
kpkg sync
kpkg search editor
kpkg info neovim
kpkg install -a neovim
kpkg upgrade
kpkg snapshots
kpkg rollback
kpkg doctor
```

Package forms: `name`, `category/name`, `name@version`. Run `kpkg help` for every command and option.

To install `kpkg` on another system:

```sh
curl -fsSL https://raw.githubusercontent.com/wh1laye/Kryonux/main/kpkg/install.sh | sh
```

## 🗺️ Repository layout

| Path | Contents |
| :--- | :--- |
| `kpkg/` | Package manager sources, configuration and installer |
| `tools/` | Stage 3, ISO and kernel build scripts, tests, forum SQL |
| `tools/kernel/` | `kryonk` configuration, overlay and boot checks |
| `docs/` | Website sources (Russian and English) |
| `.github/` | CI workflows, issue and pull request templates |

## 🏗️ Build pipeline

1. 🧠 **kryonk**: kernel built from signed upstream sources, then boot-tested in QEMU
2. 🗜️ **Stage 3**: base root filesystem assembled with `kpkg` inside a chroot
3. 💿 **Live ISO**: `squashfs` root, `kryonk` kernel and `Limine`, smoke-tested and install-tested in QEMU
4. ✍️ **Signing**: every artifact gets a `sha256` file and a `minisign` signature

## 🌐 Website

The site is static and lives in `docs/`.

- 🔗 https://wh1laye.github.io/Kryonux/
- 🔗 https://kryonux.pages.dev/

Run the site checks with `node tools/test-site.js`.

## 🤝 Contributing

Contributions are welcome: bug reports, recipes and kernel or `kpkg` improvements. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## 📜 License

Copyright © 2026 The Kryonux Project. Released under the [GNU General Public License v3.0](LICENSE).

The names "Kryonux", "kryonk" and "kpkg" and the official Kryonux crystal logo are identifiers of The Kryonux Project. Modified forks and unofficial builds distributed publicly must use a different name and logo. See [NOTICE](NOTICE) for details.

---

<div align="center">

📝 See the [CHANGELOG](CHANGELOG.md) for release history.

</div>
