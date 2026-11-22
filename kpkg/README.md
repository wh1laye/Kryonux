# 📦 kpkg 0.0.1

The standalone package manager of Kryonux. Written in C, it builds packages from source using its own `.kpkg` recipes. It is not related to Gentoo or any other package manager and does not wrap one.

## ✨ Features

- 🍳 Own recipe format: plain `.kpkg` files, see [RECIPES.md](RECIPES.md)
- 🔐 Sources are checked against the `SHA256` field of the recipe
- 📥 Install from the recipe tree or straight from a local `.kpkg` file
- 🧩 Dependency resolution with per-recipe build options
- ✍️ `minisign` signature verification for self-updates
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
| `install` | Install packages by name or from a `.kpkg` file |
| `remove` | Remove packages |
| `upgrade` | Upgrade installed packages |
| `lint` | Check `.kpkg` files for errors |
| `search`, `info`, `list` | Query recipes and installed packages |
| `files`, `owns` | Show package files or the package that owns a path |
| `snapshot`, `snapshots`, `rollback` | Manage `btrfs` snapshots |
| `doctor`, `fix` | Diagnose and repair the environment |

Run `kpkg help` for all options.

## 📜 License

Copyright © 2026 The Kryonux Project. Licensed under GNU GPLv3.
