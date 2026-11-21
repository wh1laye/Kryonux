# 📦 kpkg 2.2.0

The standalone package manager of Kryonux. Written in C, it builds packages from source using its own `.kpkg` recipes. It does not rely on any third-party package manager or wrapper.

## ✨ Features

- 🧩 Dependency resolution with per-recipe build options
- ✍️ `minisign` signature verification for sources and self-updates
- 📸 Automatic `btrfs` snapshots before upgrades, with `kpkg rollback`
- 🩺 Environment diagnostics with `kpkg doctor` and `kpkg fix`

## 🔧 Build

```sh
make
```

## 📚 Commands

| Command | Purpose |
| :--- | :--- |
| `sync` | Download the recipe tree (kpkg-recipes) |
| `update` | Update kpkg itself from GitHub releases |
| `install` / `remove` | Install or remove packages |
| `upgrade` | Upgrade installed packages |
| `search` / `info` / `list` | Query recipes and installed packages |
| `files` / `owns` | Show package files or the package that owns a path |
| `snapshot` / `snapshots` / `rollback` | Manage `btrfs` snapshots |
| `doctor` / `fix` | Diagnose and repair the environment |

Run `kpkg help` for all options.

## 📜 License

Copyright © 2026 The Kryonux Project. Licensed under GNU GPLv3.
