#!/bin/bash
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$(dirname "$HERE")")
KVER=${1:-}
KEY=${MINISIGN_KEY:-}
PIN=${PIN:-$HERE/kernel-pin.txt}
WORK=${WORK:-/var/tmp/kryonk-pin}

say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
for c in curl tar xz gpg sha256sum awk sort; do
  command -v "$c" >/dev/null || die "missing command: $c"
done
. "$HERE/lib.sh"
mkdir -p "$WORK"

if [ -z "$KVER" ]; then
  KVER=$(kernel_latest "$WORK/index.html") || die "cannot read the kernel.org index"
  [ -n "$KVER" ] || die "cannot detect the latest $KERNEL_SERIES kernel"
fi
say "kernel $KVER"
kernel_get "$KVER" "$WORK"
SUM=$(sha256sum "$WORK/linux-$KVER.tar.xz" | awk '{print $1}')

touch "$PIN"
grep -v "^$KVER " "$PIN" > "$PIN.new" || true
printf '%s %s\n' "$KVER" "$SUM" >> "$PIN.new"
sort -V "$PIN.new" -o "$PIN"
rm -f "$PIN.new"
say "pinned: $KVER $SUM"

if [ -n "$KEY" ]; then
  command -v minisign >/dev/null 2>&1 || die "minisign is missing"
  minisign -Sm "$PIN" -s "$KEY" -x "$PIN.minisig"
  say "pin signed with the Kryonux key"
else
  say "MINISIGN_KEY is not set, the pin is unsigned"
fi
say "commit $PIN and $PIN.minisig, public key: $REPO/docs/kryonux.pub"
