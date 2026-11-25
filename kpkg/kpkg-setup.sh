#!/bin/bash
set -eu

REPO=${KPKG_REPO:-wh1laye/Kryonux}
BRANCH=${KPKG_BRANCH:-main}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || HERE="$(pwd)"
SRC="${KPKG_SRC:-}"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

NOSYNC=""
for a in "$@"; do
  case $a in
    --no-sync) NOSYNC=1 ;;
    *) printf 'error: unknown option %s\n' "$a" >&2; exit 1 ;;
  esac
done

TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; return 0; }
trap cleanup EXIT
say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "root is required"

if [ -r /etc/os-release ] && ! grep -q '^ID=.\?kryonux' /etc/os-release && [ -z "${KPKG_FORCE:-}" ]; then
  die "this is not Kryonux; on another distribution use install.sh (isolated box mode), it does not touch your system"
fi

for c in bash curl tar gcc make; do
  command -v "$c" >/dev/null || die "missing command: $c"
done

TMP=$(mktemp -d /var/tmp/kpkg-setup.XXXXXX)

if [ -z "$SRC" ]; then
  if [ -f "$HERE/kpkg.c" ]; then
    SRC="$HERE"
  else
    command -v minisign >/dev/null || die "minisign is required to verify the kpkg sources"
    [ -f /etc/kpkg/kryonux.pub ] || die "public key /etc/kpkg/kryonux.pub is missing"
    say "downloading signed kpkg sources"
    REL=https://github.com/$REPO/releases/download/kpkg-latest
    curl -fL --proto =https --retry 3 --connect-timeout 20 -o "$TMP/repo.tar.gz" "$REL/kpkg-src.tar.gz"
    curl -fL --proto =https --retry 3 --connect-timeout 20 -o "$TMP/repo.tar.gz.minisig" "$REL/kpkg-src.tar.gz.minisig"
    minisign -Vq -p /etc/kpkg/kryonux.pub -x "$TMP/repo.tar.gz.minisig" -m "$TMP/repo.tar.gz" || die "source signature mismatch"
    say "minisign signature verified"
    tar xf "$TMP/repo.tar.gz" -C "$TMP" --no-same-owner
    SRC=$(echo "$TMP"/*/kpkg)
  fi
fi
[ -f "$SRC/kpkg.c" ] || die "no $SRC/kpkg.c"
say "sources: $SRC"

mkdir -p /var/db/repos /var/db/kpkg/installed /var/cache/kpkg/distfiles /var/tmp/kpkg-build

say "building kpkg"
cd "$SRC"
make clean
make
make install
make conf

SYNC_FAIL=""
if [ -z "$NOSYNC" ]; then
  say "kpkg sync"
  kpkg sync || SYNC_FAIL=1
fi

kpkg doctor || true
if [ -z "$SYNC_FAIL" ]; then
  echo CP_OK
else
  echo "kpkg is installed, but the recipe tree was not downloaded"
  echo "check the network and run: kpkg sync"
  exit 3
fi
