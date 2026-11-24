# 🛠️ Kryonux build tools

Scripts for building the base system (stage 3), the live ISO and the `kryonk` kernel, plus the test suites.

## 🗜️ Building stage 3

`build-stage3.sh` starts a chroot and runs `stage3/build-inside.sh`, which installs packages with `kpkg` from the list in `stage3/kryonux-packages.list`.

The first stage 3 has no previous base: without `BASE` (or `BASE_TAG` and `BASE_VERSION`) the script bootstraps a minimal seed with `debootstrap`, builds everything with `kpkg` and removes the seed `apt` and `dpkg` before packing. Later builds can run inside an earlier base: `BASE_TAG=base-0.0.1 BASE_VERSION=0.0.1 sudo -E bash tools/build-stage3.sh`.

## 💿 Building the live ISO

`mkiso.sh` unpacks the stage 3 archive and the `kryonk` kernel, then `iso/mkiso-inside.sh` assembles the `squashfs` image and the `Limine` boot setup.

## 🧠 Building the kernel

`kernel/build-kryonk.sh` builds `kryonk` from pinned upstream sources. The pin and checksums are stored in `kernel/kernel-pin.txt`.

## 🧪 Tests

The `test-*.sh` scripts cover `kpkg`, the firewall, hardening, snapshots, forum policies and update signing. `test-site.js` checks the website.

```sh
node tools/test-site.js
```

## 📜 License

Copyright © 2026 The Kryonux Project. Licensed under GNU GPLv3. Package recipes live in [kpkg-recipes](https://github.com/wh1laye/kpkg-recipes).
