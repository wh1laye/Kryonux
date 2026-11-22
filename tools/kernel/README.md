# 🧠 kryonk

`kryonk` is the Kryonux fork of the Linux 6.18 LTS kernel. It is not a separate tree: the build downloads the newest `linux-6.18.y` release from kernel.org, verifies its PGP signature, applies the Kryonux patch series and builds it with the hardened `kryonk.config`.

## 🔧 The patch series

The series lives in `patches/` and is listed in `patches/series`. Patches are applied in order with `patch -p1`.

| Patch | What it does |
| :--- | :--- |
| `0001-security-add-kryonk-guard.patch` | Adds `security/kryonk`. At boot it sets `kptr_restrict=2`, `dmesg_restrict=1` and `panic_on_oops=1`, and creates `/proc/kryonk`. Boot with `kryonk.guard=0` to disable it |
| `0002-security-kryonk-add-lock-sysctl.patch` | Adds the one-way sysctl `kernel.kryonk.lock`. Writing `1` re-asserts the guard values and disables module loading until reboot. It cannot be changed back |
| `0003-security-kryonk-report-lock-state.patch` | Shows the lock state and the module loading state in `/proc/kryonk` |

Use it after boot, for example at the end of your init sequence:

```sh
sysctl -w kernel.kryonk.lock=1
cat /proc/kryonk
```

Besides the patches, `kryonk-source.sh` wires `security/kryonk` into the kernel build and changes a few defaults (`kptr_restrict`, dirty page ratios, swappiness). In strict mode (`STRICT=1`) the build fails when one of these edits does not apply.

## ⚙️ Configuration

`kryonk.config` is merged on top of `x86_64_defconfig`. It enables KSPP style hardening, signed modules, Landlock, Yama and AppArmor, and turns off risky legacy interfaces such as `kexec`, hibernation, `/proc/kcore` and `TIOCSTI`.

## 🏗️ Building

```sh
bash tools/kernel/build-kryonk.sh
```

Useful variables:

| Variable | Meaning |
| :--- | :--- |
| `KERNEL_SERIES` | Kernel series to follow, default `6.18` |
| `KVER` | Exact version, default the latest in the series |
| `KRYONK_VER` | `kryonk` version, default `0.0.1` |
| `MARCH` | CPU level such as `x86-64-v3` |
| `STRICT` | `1` fails the build on unpinned sources and on defaults that did not apply |
| `MINISIGN_KEY` | Path to a minisign secret key file, or the key text, used to sign artifacts |
| `MINISIGN_PASSWORD` | Password of the key, empty for a key without a password |

Pin a release with `tools/kernel/pin-kernel.sh`.

## 🧪 Tests

`tools/test-kernel-patches.sh` downloads the newest kernel of the series, verifies the PGP signature, applies the whole series and checks the result.

## ✍️ Signing in CI

The `kryonk` workflow signs every artifact. Add the repository secret `MINISIGN_KEY` with the full contents of your minisign secret key file. For a key that has a password also add `MINISIGN_PASSWORD`. Create a key without a password with `minisign -G -W`.
