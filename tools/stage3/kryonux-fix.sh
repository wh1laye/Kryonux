#!/bin/bash
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
say() { printf '==> %s\n' "$*"; }
[ "$(id -u)" = 0 ] || { echo "root is required" >&2; exit 1; }
for a in "$@"; do
  echo "usage: kryonux-fix" >&2
  exit 1
done
say "updating kpkg from the signed release"
kpkg update
say "refreshing the recipe tree (minisign is checked)"
kpkg sync
kpkg doctor || true
