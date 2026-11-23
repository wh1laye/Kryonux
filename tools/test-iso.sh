#!/bin/bash
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$HERE")
pass=0
fail=0

ok() { printf 'PASS  %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL  %s\n' "$1"; fail=$((fail+1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

KPKG_VER=$(sed -n 's/^#define VERSION "\(.*\)"/\1/p' "$REPO/kpkg/kpkg.c" | head -1)
MK=$HERE/mkiso.sh
INS=$HERE/iso/kryonux-install
KCFG=$HERE/kernel/kryonk-config.sh
LIST=$HERE/stage3/kryonux-packages.list

while read -r f; do
  [ -n "$f" ] || continue
  check "file exists: $f" "[ -f '$HERE/$f' ]"
done < <(sed -n 's/.*for f in \(iso\/[^;]*\); do.*/\1/p' "$MK" | tr ' ' '\n')

for f in "$HERE"/iso/init "$HERE"/iso/mkiso-inside.sh "$HERE"/iso/kryonux-install "$HERE"/iso/kryonux-secureboot "$HERE"/iso/kryonux-uki "$HERE"/iso/kryonux-tpm2 "$MK" "$HERE"/build-stage3.sh; do
  check "syntax: ${f#"$HERE"/}" "bash -n '$f'"
done

check "kpkg version is set" "[ -n '$KPKG_VER' ]"
check "mkiso.sh default version matches kpkg" "grep -q 'VERSION=\${VERSION:-$KPKG_VER}' '$MK'"
check "mkiso.sh kernel version matches kpkg" "grep -q 'KRYONK_VER=\${KRYONK_VER:-$KPKG_VER}' '$MK'"
check "mkiso-inside.sh default version matches kpkg" "grep -q 'VERSION=\${1:-$KPKG_VER}' '$HERE/iso/mkiso-inside.sh'"
check "build-stage3.sh default version matches kpkg" "grep -q 'VERSION=\${VERSION:-$KPKG_VER}' '$HERE/build-stage3.sh'"
check "iso workflow version matches kpkg" "awk '/^      version:/{f=1} f&&/default:/{print; exit}' '$REPO/.github/workflows/iso.yml' | grep -q '\"$KPKG_VER\"'"
check "stage3 workflow version matches kpkg" "awk '/^      version:/{f=1} f&&/default:/{print; exit}' '$REPO/.github/workflows/stage3.yml' | grep -q '\"$KPKG_VER\"'"
check "ISO consumes the stage3 of the same version" "grep -q 'BASE_VERSION=\${BASE_VERSION:-$KPKG_VER}' '$MK'"
check "ISO is named kryonux-live-amd64" "grep -q 'kryonux-live-amd64' '$MK'"
check "stage3 is named kryonux-stage3-amd64" "grep -q 'kryonux-stage3-amd64' '$MK' && grep -q 'kryonux-stage3-amd64' '$HERE/build-stage3.sh'"

for s in ISO9660_FS SQUASHFS SQUASHFS_XZ OVERLAY_FS EXT4_FS BTRFS_FS VFAT_FS EFI EFI_STUB BLK_DEV_DM DM_CRYPT; do
  check "kernel builds in $s for the live system" "grep -qw '$s' '$KCFG'"
done

check "live init mounts the squashfs root" "grep -q 'squashfs' '$HERE/iso/init'"
check "live init builds an overlay" "grep -q 'overlay' '$HERE/iso/init'"
check "installer uses limine" "grep -q 'limine' '$INS'"
check "installer can format ext4" "grep -q 'mkfs.ext4' '$INS'"
check "installer can format btrfs" "grep -q 'mkfs.btrfs' '$INS'"
check "installer reads the squashfs from the ISO" "grep -q 'rootfs.squashfs' '$INS'"

for p in toolchain/gcc toolchain/binutils system/glibc system/linux-headers init/openrc boot/limine system/kmod system/eudev system/util-linux fs/e2fsprogs fs/dosfstools fs/btrfs-progs network/dhcpcd network/openssh network/nftables admin/doas tools/minisign tools/fastfetch tools/squashfs-tools tools/libisoburn fs/cryptsetup libs/zstd tools/cpio; do
  check "stage3 list has $p" "grep -qx '$p' '$LIST'"
done
check "stage3 list has no duplicates" "[ -z \"\$(sort '$LIST' | uniq -d)\" ]"
check "stage3 list uses our categories" "! grep -vE '^(system|fs|network|toolchain|build|tools|libs|boot|init|admin)/[a-z0-9+._-]+$' '$LIST'"
check "no foreign names in the ISO and stage3 scripts" "! grep -rIiE 'gentoo|portage|cachy|kryounix|cloudos' '$HERE/iso' '$HERE/stage3' '$MK' '$HERE/build-stage3.sh'"
check "kernel patch series is complete" "while read -r n; do [ -f '$HERE/kernel/patches/'\"\$n\" ] || exit 1; done < '$HERE/kernel/patches/series'"

printf '\niso tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
