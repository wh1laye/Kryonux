#!/bin/bash
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
VERSION=${VERSION:-0.0.1}
KVER=${KVER:-6.18.10}
MARCH=${MARCH:-x86-64-v3}
BASE_TAG=${BASE_TAG:-base-0.0.1}
KRYONK_VER=${KRYONK_VER:-0.0.1}
KRYONK_TAG=${KRYONK_TAG:-kryonk-$KRYONK_VER}
KRYONK=${KRYONK:-https://github.com/wh1laye/Kryonux/releases/download/$KRYONK_TAG}
KRYONK_VERIFY=${KRYONK_VERIFY:-1}
PUB=${PUB:-$(dirname "$HERE")/docs/kryonux.pub}
MINISIGN_KEY=${MINISIGN_KEY:-}
BASE_VERSION=${BASE_VERSION:-0.0.1}
BASE_VERIFY=${BASE_VERIFY:-1}
BASE=${BASE:-https://github.com/wh1laye/Kryonux/releases/download/$BASE_TAG/kryonux-stage3-amd64-$BASE_VERSION.tar.xz}
WORK=${WORK:-/var/tmp/kryonux-iso-build}
OUT=${OUT:-$PWD}
ROOT=$WORK/root
NAME=kryonux-live-amd64-$VERSION.iso

say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
case $MARCH in x86-64|x86-64-v2|x86-64-v3|x86-64-v4) ;; *) die "MARCH: x86-64, x86-64-v2, x86-64-v3 or x86-64-v4" ;; esac
[ "$(id -u)" = 0 ] || die "root is required: sudo $0"
[ "$(uname -m)" = x86_64 ] || die "x86_64 is required"
for c in curl tar xz sha256sum unshare mount chroot awk; do command -v "$c" >/dev/null || die "missing command: $c"; done
case $WORK in /|/usr*|/etc*|/home|/root|/var|/boot) die "unsafe work directory: $WORK" ;; esac
for f in iso/init iso/mkiso-inside.sh iso/kryonux-install iso/kryonux-secureboot iso/kryonux-uki iso/kryonux-tpm2 iso/dracut-tpm2/module-setup.sh iso/dracut-tpm2/kryonux-tpm2-unlock.sh iso/sysctl-perf.conf stage3/kryonux-audit; do
  [ -f "$HERE/$f" ] || die "no $HERE/$f"
done

mkdir -p "$WORK/src" "$OUT"

fetch() { curl -fL --retry 3 --connect-timeout 20 -C - -sS -o "$2" "$1"; }

base_sig() {
  case $BASE_VERIFY in
    1)
      command -v minisign >/dev/null || die "minisign is missing (BASE_VERIFY=0 disables the check)"
      [ -f "$PUB" ] || die "public key not found: $PUB"
      [ -f "$2" ] || die "signature not found: $2"
      minisign -V -p "$PUB" -m "$1" -x "$2" >/dev/null || die "base signature does not match $PUB"
      say "base minisign signature verified" ;;
    0) printf 'warning: base signature is not verified\n' >&2 ;;
    *) die "BASE_VERIFY: 1 or 0" ;;
  esac
}

say "base: $BASE"
case $BASE in
  http*://*)
    rm -f "$WORK/base.tar.xz" "$WORK/base.sha256"
    fetch "$BASE" "$WORK/base.tar.xz" || die "download failed: $BASE"
    fetch "$BASE.sha256" "$WORK/base.sha256" || die "download failed: $BASE.sha256"
    [ "$(cut -d' ' -f1 "$WORK/base.sha256")" = "$(sha256sum "$WORK/base.tar.xz" | cut -d' ' -f1)" ] || die "base sha256 mismatch"
    rm -f "$WORK/base.minisig"
    if [ "$BASE_VERIFY" = 1 ]; then fetch "$BASE.minisig" "$WORK/base.minisig" || die "download failed: $BASE.minisig"; fi
    base_sig "$WORK/base.tar.xz" "$WORK/base.minisig"
    BASEFILE=$WORK/base.tar.xz ;;
  *)
    [ -f "$BASE" ] || die "no such file: $BASE"
    if [ -f "$BASE.sha256" ]; then
      [ "$(cut -d' ' -f1 "$BASE.sha256")" = "$(sha256sum "$BASE" | cut -d' ' -f1)" ] || die "base sha256 mismatch"
    fi
    base_sig "$BASE" "$BASE.minisig"
    BASEFILE=$BASE ;;
esac

CK=kryonk-$KRYONK_VER-$MARCH
say "kryonk $KRYONK_VER ($MARCH) from $KRYONK"
mkdir -p "$WORK/kryonk"
case $KRYONK in
  http*://*)
    rm -f "$WORK/kryonk"/*
    for f in "$CK-vmlinuz" "$CK-modules.tar.zst" "$CK-config" "$CK.sha256" "$CK.sha256.minisig"; do
      fetch "$KRYONK/$f" "$WORK/kryonk/$f" || die "download failed: $KRYONK/$f"
    done ;;
  *)
    for f in "$CK-vmlinuz" "$CK-modules.tar.zst" "$CK-config" "$CK.sha256" "$CK.sha256.minisig"; do
      [ -f "$KRYONK/$f" ] || die "no such file: $KRYONK/$f"
      cp "$KRYONK/$f" "$WORK/kryonk/$f"
    done ;;
esac
case $KRYONK_VERIFY in
  1)
    command -v minisign >/dev/null || die "minisign is missing (KRYONK_VERIFY=0 disables the check)"
    [ -f "$PUB" ] || die "public key not found: $PUB"
    minisign -V -p "$PUB" -m "$WORK/kryonk/$CK.sha256" -x "$WORK/kryonk/$CK.sha256.minisig" >/dev/null || die "kryonk signature does not match $PUB" ;;
  0) printf 'warning: kryonk signature is not verified\n' >&2 ;;
  *) die "KRYONK_VERIFY: 1 or 0" ;;
esac
( cd "$WORK/kryonk" && sha256sum -c "$CK.sha256" >/dev/null ) || die "kryonk sha256 mismatch"

say "unpacking the base into $ROOT"
rm -rf "$ROOT"
mkdir -p "$ROOT"
xz -dc "$BASEFILE" | tar -xpf - -C "$ROOT" --numeric-owner --xattrs --xattrs-include='*'
grep -qE '^ID="?(kryonux|kryonux)"?' "$ROOT/etc/os-release" || die "the base does not look like Kryonux"

mkdir -p "$ROOT/var/tmp/isosrc" "$ROOT/var/tmp/isofiles"
cp "$WORK/kryonk/$CK-vmlinuz" "$WORK/kryonk/$CK-modules.tar.zst" "$ROOT/var/tmp/isosrc/"
cp -R "$HERE"/iso/. "$ROOT/var/tmp/isofiles/"
cp "$HERE/stage3/kryonux-audit" "$ROOT/var/tmp/isofiles/"

enter() {
  unshare -m sh -c '
R=$1; shift
mount --make-rprivate / || exit 1
mount --rbind /dev "$R/dev" && mount -t proc proc "$R/proc" && mount --rbind /sys "$R/sys" && mount -t tmpfs tmpfs "$R/run" || exit 1
rm -f "$R/etc/resolv.conf"; cat /etc/resolv.conf > "$R/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" > "$R/etc/resolv.conf"
exec chroot "$R" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin HOME=/root TERM="${TERM:-xterm}" LANG=C.UTF-8 "$@"
' sh "$ROOT" "$@"
}

say "building the iso inside chroot"
enter bash /var/tmp/isofiles/mkiso-inside.sh "$VERSION" "$KVER" "$NAME" "$MARCH" "$KRYONK_VER" || die "the chroot build stopped, see the reason above"

[ -s "$ROOT/var/tmp/isoout/$NAME" ] || die "the iso did not appear"
mv "$ROOT/var/tmp/isoout/$NAME" "$OUT/$NAME"
( cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256" )
if [ -n "$MINISIGN_KEY" ]; then
  say "signing $NAME"
  MINISIGN_KEY="$MINISIGN_KEY" MINISIGN_PASSWORD="${MINISIGN_PASSWORD:-}" bash "$HERE/sign.sh" "$OUT/$NAME" "$OUT/$NAME.sha256"
else
  say "MINISIGN_KEY is not set, artifacts are unsigned"
fi
SIZE=$(stat -c %s "$OUT/$NAME")
[ "$SIZE" -lt 2147483648 ] || printf 'warning: iso is %s bytes, the GitHub release limit is 2 GB\n' "$SIZE" >&2
say "done: $OUT/$NAME ($(du -h "$OUT/$NAME" | cut -f1))"
cat "$OUT/$NAME.sha256"
