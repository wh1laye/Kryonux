#!/bin/bash
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SRC_HOME="$HERE/kernel"
T=$(mktemp -d)
KRYONK_VER=${KRYONK_VER:-0.0.1}
export KRYONK_VER
trap 'rm -rf "$T"' EXIT

fail() { printf 'fail: %s\n' "$*" >&2; exit 1; }
ok() { printf 'ok: %s\n' "$*"; }
say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
export -f say die

for c in curl gpg tar xz patch; do
  command -v "$c" >/dev/null || fail "$c is required"
done
for f in lib.sh kryonk-source.sh patches/series kryonk.config; do
  [ -f "$SRC_HOME/$f" ] || fail "missing $SRC_HOME/$f"
done
. "$SRC_HOME/lib.sh"

while read -r name; do
  case $name in ''|\#*) continue ;; esac
  [ -f "$SRC_HOME/patches/$name" ] || fail "the series lists a missing patch: $name"
done < "$SRC_HOME/patches/series"
ok "every patch in the series exists"

KVER=${KVER:-$(kernel_latest "$T/index.html")}
[ -n "$KVER" ] || fail "cannot detect the latest $KERNEL_SERIES kernel"
kernel_get "$KVER" "$T"
ok "kernel.org PGP signature verifies for linux-$KVER"

printf 'fake\n' > "$T/bad.sign"
if kernel_pgp "$T/linux-$KVER.tar.xz" "$T/bad.sign"; then
  fail "a forged signature was accepted"
fi
ok "a forged signature is rejected"

mkdir -p "$T/src"
tar -xf "$T/linux-$KVER.tar.xz" -C "$T/src" --strip-components=1
[ -f "$T/src/Makefile" ] && [ -d "$T/src/security" ] || fail "the archive is not a kernel tree"
(
  cd "$T/src"
  while read -r name; do
    case $name in ''|\#*) continue ;; esac
    patch -p1 --forward --batch -N < "$SRC_HOME/patches/$name" >/dev/null
  done < "$SRC_HOME/patches/series"
  STRICT=1
  . "$SRC_HOME/kryonk-source.sh"
  kryonk_source
) || fail "the kryonk series or source edits do not apply to linux-$KVER"
ok "the kryonk series and source edits apply to linux-$KVER"

grep -q 'SECURITY_KRYONK' "$T/src/security/Makefile" || fail "the guard is not wired into security/Makefile"
ok "the guard is wired into the build"
echo "all tests passed"
