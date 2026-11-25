#!/bin/bash
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$HERE")
cd "$REPO"

fail=0
ok() { printf 'ok       %s\n' "$*"; }
bad() { printf 'FAIL     %s\n' "$*"; fail=1; }

need_file() { if [ -f "$1" ]; then ok "$1"; else bad "missing $1"; fi; }
forbid_file() { if [ -e "$1" ]; then bad "forbidden $1"; else ok "absent $1"; fi; }
need_text() { if grep -qE "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$3"; fi; }
forbid_text() { if grep -qE "$2" "$1" 2>/dev/null; then bad "$3"; else ok "$3"; fi; }

ARCHIVE=${1:-}

if [ -n "$ARCHIVE" ]; then
  printf '==> stage3 gate: archive %s\n' "$ARCHIVE"
  [ -f "$ARCHIVE" ] || { printf 'no such file: %s\n' "$ARCHIVE" >&2; exit 1; }
  LIST=$(mktemp)
  trap 'rm -f "$LIST"' EXIT
  tar -tf "$ARCHIVE" > "$LIST"
  need_entry() { if grep -qxE "(\./)?(usr/)?$1" "$LIST"; then ok "$1"; else bad "missing $1"; fi; }
  forbid_entry() { if grep -qxE "(\./)?$1" "$LIST"; then bad "forbidden $1"; else ok "absent $1"; fi; }
  need_entry usr/bin/kpkg
  need_entry usr/bin/kpkg
  need_entry etc/kpkg/config.kpkg
  need_entry etc/kpkg/kryonux.pub
  need_entry etc/os-release
  need_entry sbin/openrc-init
  need_entry etc/doas.conf
  need_entry usr/sbin/kryonux-install
  forbid_entry usr/bin/emerge
  forbid_entry usr/bin/emaint
  forbid_entry etc/portage/make.conf
  forbid_entry var/db/repos/gentoo
  if grep -qE '^(\./)?var/db/kpkg/' "$LIST"; then
    ok "kpkg database present"
  else
    ok "kpkg database empty, packages built manually"
  fi
else
  printf '==> stage3 gate: repository\n'
  need_file tools/build-stage3.sh
  need_file tools/stage3/build-inside.sh
  need_file tools/stage3/kryonux-packages.list
  need_file tools/kernel/patches/series
  need_file kpkg/kpkg.c
  need_file kpkg/Makefile
  need_file tools/kernel/kryonk.config
  need_file tools/kernel/patches/0001-security-add-kryonk-guard.patch
  forbid_file tools/stage3/gentoo-stage3.list
  forbid_file tools/stage3/gentoo-exclude.txt
  forbid_file tools/stage3/refresh-list.sh
  need_text tools/stage3/build-inside.sh 'kpkg' "build-inside uses kpkg"
  forbid_text tools/stage3/build-inside.sh 'portageq|/etc/portage|/var/db/repos/gentoo' "build-inside has no foreign package manager paths"
  need_text tools/stage3/kryonux-packages.list '^(system|fs|network|toolchain|build|tools|libs|boot|init|admin)/' "package list uses our categories"
  forbid_text tools/stage3/kryonux-packages.list '^(sys-apps|sys-libs|sys-devel|dev-libs|dev-build|dev-lang|app-|net-|virtual|acct-)' "package list has no foreign categories"
  forbid_text tools/build-stage3.sh 'base-0\.0\.0' "stage 3 has no default base release"
  need_text tools/build-stage3.sh 'debootstrap' "stage 3 can bootstrap without a base release"
  need_text kpkg/Makefile 'non-Kryonux' "make install refuses foreign systems"
  need_text tools/kernel/kryonk.config 'CONFIG_SECURITY_KRYONK=y' "kernel has the kryonk layer"
fi

if [ "$fail" = 0 ]; then
  printf 'stage3 gate: PASS\n'
else
  printf 'stage3 gate: FAIL\n'
fi
exit "$fail"
