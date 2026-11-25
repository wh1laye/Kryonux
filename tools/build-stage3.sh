#!/bin/bash
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$HERE")
VERSION=${VERSION:-0.0.1}
BASE_TAG=${BASE_TAG:-}
BASE_VERSION=${BASE_VERSION:-}
SEED_SUITE=${SEED_SUITE:-noble}
SEED_MIRROR=${SEED_MIRROR:-http://archive.ubuntu.com/ubuntu}
BASE_VERIFY=${BASE_VERIFY:-1}
PUB=${PUB:-$REPO/docs/kryonux.pub}
MINISIGN_KEY=${MINISIGN_KEY:-}
BASE=${BASE:-}
if [ -z "$BASE" ] && [ -n "$BASE_TAG" ] && [ -n "$BASE_VERSION" ]; then
  BASE=https://github.com/wh1laye/Kryonux/releases/download/$BASE_TAG/kryonux-stage3-amd64-$BASE_VERSION.tar.xz
fi
SEEDED=0
RECIPES_TARBALL=${RECIPES_TARBALL:-}
WORK=${WORK:-/var/tmp/kryonux-stage3-build}
OUT=${OUT:-$PWD}
ROOT=$WORK/root

say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || die "root is required: sudo $0"
[ "$(uname -m)" = x86_64 ] || die "x86_64 is required"
for c in curl tar xz sha256sum unshare mount chroot; do command -v "$c" >/dev/null || die "missing command: $c"; done
case $WORK in /|/usr*|/etc*|/home|/root|/var|/boot) die "unsafe work directory: $WORK" ;; esac

mkdir -p "$OUT"

fetch() { curl -fL --proto =https --retry 8 --retry-delay 15 --connect-timeout 20 -C - -sS -o "$2" "$1"; }

base_sig() {
  case $BASE_VERIFY in
    1)
      command -v minisign >/dev/null || die "minisign is missing (BASE_VERIFY=0 disables it)"
      [ -f "$PUB" ] || die "public key not found: $PUB"
      [ -f "$2" ] || die "signature not found: $2"
      minisign -V -p "$PUB" -m "$1" -x "$2" >/dev/null || die "base signature does not match $PUB"
      say "base minisign signature verified" ;;
    0) printf 'warning: base signature is not verified\n' >&2 ;;
    *) die "BASE_VERIFY: 1 or 0" ;;
  esac
}

seed_root() {
  command -v debootstrap >/dev/null || die "debootstrap is missing, it is needed to bootstrap the first stage 3"
  say "no base release: bootstrapping the first stage 3 from a $SEED_SUITE seed"
  rm -rf "$ROOT"; mkdir -p "$ROOT"
  debootstrap --variant=minbase --components=main,universe \
    --include=build-essential,ca-certificates,curl,xz-utils,perl,python3,texinfo,bison,flex,m4,gawk,bc,file,gnupg,minisign \
    "$SEED_SUITE" "$ROOT" "$SEED_MIRROR" || die "debootstrap failed"
  printf 'NAME="Kryonux"\nID=kryonux\nPRETTY_NAME="Kryonux"\nVERSION_ID="%s"\n' "$VERSION" > "$ROOT/etc/os-release"
  SEEDED=1
}

unseed() {
  say "removing the seed package manager"
  rm -rf "$ROOT/var/lib/dpkg" "$ROOT/var/lib/apt" "$ROOT/var/cache/apt" "$ROOT/var/log/apt" \
    "$ROOT/etc/apt" "$ROOT/etc/dpkg" "$ROOT/usr/share/doc" "$ROOT/usr/share/man" "$ROOT/usr/share/info"
  for b in apt apt-get apt-cache apt-config apt-key apt-mark apt-cdrom dpkg dpkg-deb dpkg-query dpkg-divert dpkg-split dpkg-trigger dpkg-statoverride dpkg-maintscript-helper; do
    rm -f "$ROOT/usr/bin/$b" "$ROOT/usr/sbin/$b"
  done
}

if [ -n "$BASE" ]; then
  say "base: $BASE"
fi
case $BASE in
  '')
    BASEFILE='' ;;
  http*://*)
    mkdir -p "$WORK"
    fetch "$BASE" "$WORK/base.tar.xz" || die "download failed: $BASE"
    fetch "$BASE.sha256" "$WORK/base.sha256" || die "download failed: $BASE.sha256"
    [ "$(cut -d' ' -f1 "$WORK/base.sha256")" = "$(sha256sum "$WORK/base.tar.xz" | cut -d' ' -f1)" ] || die "base sha256 mismatch"
    rm -f "$WORK/base.minisig"
    if [ "$BASE_VERIFY" = 1 ]; then fetch "$BASE.minisig" "$WORK/base.minisig" || die "download failed: $BASE.minisig"; fi
    base_sig "$WORK/base.tar.xz" "$WORK/base.minisig"
    BASEFILE=$WORK/base.tar.xz ;;
  *)
    [ -f "$BASE" ] || die "no such file: $BASE"
    base_sig "$BASE" "$BASE.minisig"
    BASEFILE=$BASE ;;
esac

if [ "${RESUME:-0}" = 1 ] && [ -d "$ROOT/var/tmp/s3stamp" ]; then
  say "RESUME=1: continuing in $ROOT"
  [ -d "$ROOT/var/lib/dpkg" ] && SEEDED=1
elif [ -z "$BASEFILE" ]; then
  seed_root
else
  say "unpacking the base into $ROOT"
  rm -rf "$ROOT"; mkdir -p "$ROOT"
  xz -dc "$BASEFILE" | tar -xpf - -C "$ROOT" --numeric-owner --xattrs --xattrs-include='*'
fi
grep -qE '^ID="?kryonux"?' "$ROOT/etc/os-release" || die "the base does not look like Kryonux stage 3"

mkdir -p "$ROOT/var/tmp/s3files" "$ROOT/var/tmp/kpkg-src"
cp -R "$HERE"/stage3/. "$ROOT/var/tmp/s3files/"
cp -R "$REPO"/kpkg/. "$ROOT/var/tmp/kpkg-src/"
if [ -n "$RECIPES_TARBALL" ]; then
  [ -s "$RECIPES_TARBALL" ] && [ -s "$RECIPES_TARBALL.minisig" ] || die "RECIPES_TARBALL needs the file and its .minisig"
  command -v minisign >/dev/null || die "minisign is missing"
  minisign -V -p "$PUB" -m "$RECIPES_TARBALL" -x "$RECIPES_TARBALL.minisig" >/dev/null || die "recipe tree signature does not match $PUB"
  cp "$RECIPES_TARBALL" "$ROOT/var/tmp/recipes.tar.gz"
  cp "$RECIPES_TARBALL.minisig" "$ROOT/var/tmp/recipes.tar.gz.minisig"
fi

enter() {
  unshare -m sh -c '
R=$1; shift
mount --make-rprivate / || exit 1
mount --rbind /dev "$R/dev" && mount -t proc proc "$R/proc" && mount --rbind /sys "$R/sys" && mount -t tmpfs tmpfs "$R/run" || exit 1
rm -f "$R/etc/resolv.conf"; cat /etc/resolv.conf > "$R/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" > "$R/etc/resolv.conf"
for ca in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/ca-bundle.pem; do
  if [ -s "$ca" ] && [ -f "$R/etc/ssl/certs/ca-certificates.crt" ]; then mount --bind "$ca" "$R/etc/ssl/certs/ca-certificates.crt"; break; fi
done
exec chroot "$R" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin HOME=/root TERM="${TERM:-xterm}" LANG=C.UTF-8 "$@"
' sh "$ROOT" "$@"
}

say "building packages with kpkg"
enter bash /var/tmp/s3files/build-inside.sh "$VERSION" "${STRICT:-0}" \
  || {
    if [ -s "$ROOT/var/tmp/kryonux-report.txt" ]; then cp "$ROOT/var/tmp/kryonux-report.txt" "$OUT/kryonux-stage3-amd64-$VERSION.failed.txt"; fi
    die "the chroot build stopped, see the reason above; fix it and rerun with RESUME=1"
  }

rm -f "$ROOT/etc/resolv.conf"
[ "$SEEDED" = 1 ] && unseed
NAME=kryonux-stage3-amd64-$VERSION.tar.xz

if [ -s "$ROOT/var/tmp/kryonux-report.txt" ]; then
  cp "$ROOT/var/tmp/kryonux-report.txt" "$OUT/kryonux-stage3-amd64-$VERSION.failed.txt"
  printf 'warning: some packages failed, list in %s\n' "$OUT/kryonux-stage3-amd64-$VERSION.failed.txt" >&2
  cat "$ROOT/var/tmp/kryonux-report.txt" >&2
  if [ "${STRICT:-0}" = 1 ]; then die "STRICT=1: the report has problems, the base is not released"; fi
fi
rm -f "$ROOT/var/tmp/kryonux-report.txt"

{
  echo "# kryonux $VERSION stage 3: composition"
  echo "# built from source, tracked by kpkg"
  ( cd "$ROOT/var/db/kpkg/installed" 2>/dev/null && for d in */*/*/; do echo "${d%/}"; done | sort )
} > "$OUT/kryonux-stage3-amd64-$VERSION.packages.txt"

say "packing: $OUT/$NAME"
tar -C "$ROOT" --numeric-owner --xattrs --xattrs-include='*' \
  --exclude=./var/tmp/s3stamp --exclude=./var/tmp/s3log \
  --exclude=./var/tmp/kpkg-build/* --exclude=./var/tmp/kpkg-src/* \
  --exclude=./var/tmp/recipes.tar.gz --exclude=./var/tmp/recipes.tar.gz.minisig --exclude=./var/cache/kpkg/distfiles/* -cpf - . | xz -T0 -9 > "$OUT/$NAME"

say "checking the archive"
LIST=$(mktemp); trap 'rm -f "$LIST"' EXIT
tar -tf "$OUT/$NAME" > "$LIST"
miss=0
for f in sbin/init sbin/openrc-init etc/os-release etc/init.d/syslog-ng etc/runlevels/default/syslog-ng \
         etc/syslog-ng/syslog-ng.conf usr/bin/kpkg usr/bin/fastfetch etc/xdg/fastfetch/config.jsonc etc/kpkg/kpkg.conf etc/kpkg/config.kpkg etc/kpkg/kryonux.pub \
         usr/sbin/kryonux-users usr/sbin/kryonux-adduser usr/sbin/kryonux-fix \
         etc/login.defs etc/doas.conf; do
  grep -qxE "(\./)?(usr/)?$f" "$LIST" || { printf 'the archive has no %s\n' "$f" >&2; miss=1; }
done
[ "$miss" = 0 ] || die "the archive is incomplete"

( cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256" )
if [ -n "$MINISIGN_KEY" ]; then
  say "signing $NAME"
  MINISIGN_KEY="$MINISIGN_KEY" MINISIGN_PASSWORD="${MINISIGN_PASSWORD:-}" bash "$HERE/sign.sh" "$OUT/$NAME" "$OUT/$NAME.sha256"
else
  say "MINISIGN_KEY is not set, artifacts are unsigned"
fi
say "done: $OUT/$NAME ($(du -h "$OUT/$NAME" | cut -f1))"
cat "$OUT/$NAME.sha256"
