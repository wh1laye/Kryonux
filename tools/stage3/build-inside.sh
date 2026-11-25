#!/bin/bash
set -u

VERSION=${1:-0.0.1}
STRICT=${2:-0}

say() { printf '==> %s\n' "$*"; }

F=/var/tmp/s3files
ST=/var/tmp/s3stamp
PKG=/var/tmp/kpkg-src
L=/var/tmp/s3log
REPORT=/var/tmp/kryonux-report.txt

mkdir -p "$ST" "$L"
rm -f "$REPORT"

step() {
  local name=$1; shift
  if [ -e "$ST/$name" ]; then
    say "step $name: done, skipping"
    return 0
  fi
  say "step $name"
  if "$@" > "$L/$name.log" 2>&1; then
    touch "$ST/$name"
  else
    tail -40 "$L/$name.log" >&2
    echo "step $name failed, log: /var/tmp/s3log/$name.log" >> "$REPORT"
    return 1
  fi
}

setup_kpkg() {
  install -d /etc/kpkg /var/db/kpkg/installed /var/db/repos \
    /var/cache/kpkg/distfiles /var/tmp/kpkg-build
  cat > /etc/kpkg/kpkg.conf <<CONF
repo=/var/db/repos/kpkg-recipes
recipes_url=https://github.com/wh1laye/kpkg-recipes/releases/download/recipes-latest/kpkg-recipes.tar.gz
distdir=/var/cache/kpkg/distfiles
workdir=/var/tmp/kpkg-build
jobs=0
snapshots=0
keep_workdir=no
allow_host=yes
CONF
  install -m644 "$PKG/etc/kpkg/kryonux.pub" /etc/kpkg/kryonux.pub
  [ -e /etc/kpkg/config.kpkg ] || install -m644 "$PKG/etc/kpkg/config.kpkg" /etc/kpkg/config.kpkg
  make -C "$PKG" clean >/dev/null
  make -C "$PKG" -j"$(nproc)"
  install -m755 "$PKG/kpkg" /usr/bin/kpkg
  "$PKG/kpkg" version
}

fetch_recipes() {
  if [ -s /var/tmp/recipes.tar.gz ] && [ -s /var/tmp/recipes.tar.gz.minisig ]; then
    kpkg sync --file /var/tmp/recipes.tar.gz
  else
    kpkg sync
  fi
}

install_set() {
  local ok=0 fail=0 line log broken last=
  while read -r line; do
    case $line in ''|\#*) continue ;; esac
    say "install: $line"
    log=$L/$(printf '%s' "$line" | tr / -).log
    if kpkg install -y --force "$line" > "$log" 2>&1; then
      ok=$((ok+1))
    else
      fail=$((fail+1))
      echo "$line" >> "$REPORT"
      tail -20 "$log" >&2 || true
      broken=$(sed -n 's/^kpkg: build failed for \([^,]*\),.*/\1/p' "$log" | head -1)
      if [ -n "$broken" ] && [ "$broken" = "$last" ]; then
        echo "dependency $broken cannot be built, stopping instead of repeating the same failure" | tee -a "$REPORT" >&2
        break
      fi
      last=$broken
    fi
  done < "$F/kryonux-packages.list"
  say "packages: installed $ok, failed $fail"
  [ "$fail" = 0 ]
}

install_extra() {
  local line log
  [ -f "$F/kryonux-extra.list" ] || return 0
  while read -r line; do
    case $line in ''|\#*) continue ;; esac
    log=$L/extra-$(printf '%s' "$line" | tr / -).log
    if kpkg install -y --force "$line" > "$log" 2>&1; then
      say "extra: $line installed"
    else
      say "extra: $line skipped, see $log"
    fi
  done < "$F/kryonux-extra.list"
  return 0
}

layout() {
  [ -f "$F/logo.txt" ] && install -m644 "$F/logo.txt" /usr/share/kryonux/logo.txt
  [ -f "$F/logo.ansi" ] && install -m644 "$F/logo.ansi" /usr/share/kryonux/logo.ansi
  [ -f "$F/logo.png" ] && install -m644 "$F/logo.png" /usr/share/kryonux/logo.png
  local f src
  install -d /etc/xdg/fastfetch
  [ -f /etc/xdg/fastfetch/config.jsonc ] || install -m644 "$F/fastfetch.jsonc" /etc/xdg/fastfetch/config.jsonc
  install -d /etc/kpkg
  grep -qx fastfetch /etc/kpkg/hold 2>/dev/null || printf 'fastfetch\n' >> /etc/kpkg/hold
  for f in kryonux-users kryonux-adduser kryonux-fix kryonux-firewall kryonux-audit; do
    src=$F/$f
    [ -f "$src" ] || src=$F/$f.sh
    [ -f "$src" ] || return 1
    install -m755 "$src" /usr/sbin/$f
  done
  printf 'kryonux\n' > /etc/hostname
  grep -q '^ID=kryonux' /etc/os-release
}

clean() {
  rm -rf /var/cache/kpkg/distfiles/* /var/tmp/kpkg-build/* /var/tmp/recipes.tar.gz* \
    /var/tmp/kpkg-src /root/.cache /tmp/* /etc/resolv.conf
}

step kpkg-setup setup_kpkg || exit 1
step kpkg-recipes fetch_recipes || exit 1
step kryonux-package-set install_set || exit 1
step kryonux-extra-packages install_extra || exit 1
step kryonux-layout layout || exit 1
clean

if [ -s "$REPORT" ]; then
  say "report: $REPORT"
  cat "$REPORT" >&2
  if [ "$STRICT" = 1 ]; then
    die() { printf 'error: %s\n' "$*" >&2; exit 1; }
    die "STRICT=1: package set is incomplete"
  fi
fi
say "stage3 inside build finished"
