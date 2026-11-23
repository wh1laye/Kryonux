#!/bin/bash
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${1:-$(dirname "$HERE")/kpkg}
[ -f "$SRC/kpkg.c" ] || { printf 'no kpkg sources in %s\n' "$SRC" >&2; exit 1; }

T=$(mktemp -d /var/tmp/kpkg-test.XXXXXX)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/db" "$T/tree" "$T/src" "$T/work" "$T/dist"

cat > "$T/kpkg.conf" <<CONF
repo=$T/tree
distdir=$T/dist
workdir=$T/work
jobs=2
snapshots=0
CONF

make -C "$SRC" clean >/dev/null
cp "$SRC"/*.c "$SRC"/*.h "$T/"
gcc -O2 -std=gnu17 -Wall -Wextra -Wsign-conversion -Wformat=2 -Wno-format-truncation \
  -fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=3 \
  -DCONF="\"$T/kpkg.conf\"" -DDBDIR="\"$T/db\"" -DLOCKFILE="\"$T/lock\"" -DHOLDFILE="\"$T/hold\"" \
  -pie -Wl,-z,relro,-z,now -o "$T/kpkg" \
  "$T"/kpkg.c "$T"/util.c "$T"/lock.c "$T"/recipe.c "$T"/db.c "$T"/build.c "$T"/cmds.c "$T"/snap.c "$T"/update.c

mkdir -p "$T/pkg/hello-1.0"
printf '#!/bin/sh\necho configured\n' > "$T/pkg/hello-1.0/configure"
chmod +x "$T/pkg/hello-1.0/configure"
printf 'all:\n\tprintf "#!/bin/sh\\necho hello\\n" > hello\ninstall:\n\tmkdir -p $(DESTDIR)/usr/bin\n\tcp hello $(DESTDIR)/usr/bin/hello\n\tchmod 755 $(DESTDIR)/usr/bin/hello\n' > "$T/pkg/hello-1.0/Makefile"
tar -czf "$T/src/hello-1.0.tar.gz" -C "$T/pkg" hello-1.0

mkdir -p "$T/tree/libs/hellolib/hellolib-1.0" "$T/tree/editors/hello/hello-1.0" "$T/tree/editors/broken/broken-1.0"
cat > "$T/tree/libs/hellolib/hellolib-1.0/hellolib-1.0.kpkg" <<CPR
PACKAGE=hellolib
VERSION=1.0
DESCRIPTION="Test library"
LICENSE="MIT"
SRC_URI="$T/src/hello-1.0.tar.gz -> hellolib-1.0.tar.gz"
CPR
cat > "$T/tree/editors/hello/hello-1.0/hello-1.0.kpkg" <<CPR
PACKAGE=hello
VERSION=1.0
DESCRIPTION="Test editor"
LICENSE="MIT"
SRC_URI="$T/src/hello-1.0.tar.gz"
DEPEND="libs/hellolib"
RDEPEND="libs/hellolib"
CPR
printf 'PACKAGE=broken\nVERSION=1.0\nRDEPEND="\n' > "$T/tree/editors/broken/broken-1.0/broken-1.0.kpkg"

pass=0; fail=0
run() { "$T/kpkg" "$@" >"$T/out" 2>&1; echo $?; }
check() {
  local name=$1 want=$2 code=$3 text=$4
  if [ "$code" = "$want" ] && grep -qF "$text" "$T/out"; then
    printf 'PASS  %s\n' "$name"; pass=$((pass+1))
  else
    printf 'FAIL  %s (exit %s, wanted %s, text "%s")\n' "$name" "$code" "$want" "$text"; fail=$((fail+1))
    sed -n '1,12p' "$T/out"
  fi
}

check version 0 "$(run version)" "kpkg "
check help 0 "$(run help)" "standalone source package manager"
check search 0 "$(run search hello)" "editors/hello 1.0"
check info 0 "$(run info hello)" "libs/hellolib"
check plan 0 "$(run install -p hello)" "libs/hellolib-1.0 (dependency)"
check plan-target 0 "$(run install -p hello)" "editors/hello-1.0"
check broken 1 "$(run install -p broken)" "unterminated quoted value"
check not-installed 1 "$(run remove -p hello)" "is not installed"
check empty-list 0 "$(run list)" "no packages installed"
check owns 1 "$(run owns /usr/bin/definitely-not-tracked)" "untracked"
check clean-pretend 0 "$(run clean -p)" "would clear distfiles"
check upgrade-pretend 0 "$(run upgrade -p)" "up to date"
check doctor 1 "$(run doctor)" "system id"

mkdir -p "$T/rec"
SUM=$(sha256sum "$T/src/hello-1.0.tar.gz" | awk '{print $1}')
cat > "$T/rec/good-1.0.kpkg" <<REC
PACKAGE=good
VERSION=1.0
DESCRIPTION="Good recipe"
LICENSE="MIT"
SRC_URI="$T/src/hello-1.0.tar.gz -> good-1.0.tar.gz"
SHA256="$SUM"
build() {
  make
}
install() {
  make DESTDIR="\$DESTDIR" install
}
REC
printf 'PACKAGE=nodesc\nVERSION=1.0\nLICENSE="MIT"\nSRC_URI="%s"\nSHA256="%s"\n' "$T/src/hello-1.0.tar.gz" "$SUM" > "$T/rec/nodesc-1.0.kpkg"
printf 'PACKAGE=nosum\nVERSION=1.0\nDESCRIPTION="No checksum"\nLICENSE="MIT"\nSRC_URI="%s"\n' "$T/src/hello-1.0.tar.gz" > "$T/rec/nosum-1.0.kpkg"
printf 'PACKAGE=oldnames\nVERSION=1.0\nDESCRIPTION="Old names"\nLICENSE="MIT"\nSRC_URI="%s"\nSHA256="%s"\nsrc_compile() {\n  make\n}\nsrc_install() {\n  make DESTDIR="$DESTDIR" install\n}\n' "$T/src/hello-1.0.tar.gz" "$SUM" > "$T/rec/oldnames-1.0.kpkg"
printf 'PACKAGE=dupfunc\nVERSION=1.0\nDESCRIPTION="Duplicate"\nLICENSE="MIT"\nSRC_URI="%s"\nSHA256="%s"\nbuild() {\n  make\n}\nbuild() {\n  make\n}\n' "$T/src/hello-1.0.tar.gz" "$SUM" > "$T/rec/dupfunc-1.0.kpkg"
mkdir -p "$T/tree/tools/badsum/badsum-1.0"
printf 'PACKAGE=badsum\nVERSION=1.0\nDESCRIPTION="Wrong checksum"\nLICENSE="MIT"\nSRC_URI="%s"\nSHA256="%s"\n' "$T/src/hello-1.0.tar.gz" "0000000000000000000000000000000000000000000000000000000000000000" > "$T/tree/tools/badsum/badsum-1.0/badsum-1.0.kpkg"

check lint-good 0 "$(run lint "$T/rec/good-1.0.kpkg")" "ok:"
check lint-no-description 1 "$(run lint "$T/rec/nodesc-1.0.kpkg")" "DESCRIPTION is missing"
check lint-no-sha256 1 "$(run lint "$T/rec/nosum-1.0.kpkg")" "SHA256 is missing"
check lint-legacy-names 0 "$(run lint "$T/rec/oldnames-1.0.kpkg")" "ok:"
check lint-duplicate-function 1 "$(run lint "$T/rec/dupfunc-1.0.kpkg")" "dupfunc"
printf 'PACKAGE=patchlevel\nVERSION=9.9p1\nDESCRIPTION="Letter in the version"\nLICENSE="MIT"\nSRC_URI="%s"\nSHA256="%s"\n' "$T/src/hello-1.0.tar.gz" "$SUM" > "$T/rec/patchlevel-9.9p1.kpkg"
check lint-version-with-letters 0 "$(run lint "$T/rec/patchlevel-9.9p1.kpkg")" "ok:"
printf 'PACKAGE=badver\nVERSION=1.0 beta\nDESCRIPTION="Bad"\nLICENSE="MIT"\nSRC_URI="x"\nSHA256="y"\n' > "$T/rec/badver-1.kpkg"
check lint-bad-version 1 "$(run lint "$T/rec/badver-1.kpkg")" "invalid characters"
check lint-no-args 1 "$(run lint)" "specify at least one"
check lint-missing-file 1 "$(run lint "$T/rec/absent.kpkg")" "absent"
check local-plan 0 "$(run install -p "$T/rec/good-1.0.kpkg")" "local/good-1.0"
check local-bad-file 1 "$(run install -p "$T/rec/dupfunc-1.0.kpkg")" "not a valid recipe"

cp "$T/rec/nosum-1.0.kpkg" "$T/rec/fill-1.0.kpkg"
sed -i 's/PACKAGE=nosum/PACKAGE=fill/' "$T/rec/fill-1.0.kpkg"
check checksum-writes 0 "$(run checksum "$T/rec/fill-1.0.kpkg")" "SHA256 written"
if grep -qF "SHA256=\"$SUM\"" "$T/rec/fill-1.0.kpkg"; then printf 'PASS  checksum-value\n'; pass=$((pass+1)); else printf 'FAIL  checksum-value\n'; fail=$((fail+1)); fi
check checksum-then-lint 0 "$(run lint "$T/rec/fill-1.0.kpkg")" "ok:"
run checksum "$T/rec/fill-1.0.kpkg" >/dev/null
if [ "$(grep -c '^SHA256=' "$T/rec/fill-1.0.kpkg")" = 1 ]; then printf 'PASS  checksum-idempotent\n'; pass=$((pass+1)); else printf 'FAIL  checksum-idempotent\n'; fail=$((fail+1)); fi
check checksum-missing-source 1 "$(run checksum "$T/rec/dupfunc-1.0.kpkg")" "dupfunc"
if [ "$(id -u)" = 0 ]; then
  check install-asks-without-yes 1 "$(KPKG_FORCE=1 run install badsum)" "pass -y"
  check checksum-mismatch-blocks-install 1 "$(KPKG_FORCE=1 run install -y badsum)" "SHA256 mismatch"
  check assume-yes-env 1 "$(KPKG_ASSUME_YES=1 KPKG_FORCE=1 run install badsum)" "SHA256 mismatch"
fi
check unknown-command 1 "$(run frobnicate)" "usage"

check hold-empty 0 "$(run hold)" "no packages are held"
check hold-add 0 "$(run hold fastfetch)" "fastfetch is held"
check hold-list 0 "$(run hold)" "fastfetch"
run hold fastfetch >/dev/null
if [ "$(grep -c '^fastfetch$' "$T/hold")" = 1 ]; then printf 'PASS  hold-idempotent\n'; pass=$((pass+1)); else printf 'FAIL  hold-idempotent\n'; fail=$((fail+1)); fi
check hold-invalid-name 1 "$(run hold 'bad name')" "invalid package name"
check hold-release 0 "$(run unhold fastfetch)" "is released"
if ! grep -q fastfetch "$T/hold"; then printf 'PASS  hold-file-cleared\n'; pass=$((pass+1)); else printf 'FAIL  hold-file-cleared\n'; fail=$((fail+1)); fi

if [ "$(id -u)" = 0 ]; then
  mkdir -p "$T/e2e/e2e-1.0"
  echo data > "$T/e2e/e2e-1.0/README"
  tar -czf "$T/src/e2e-1.0.tar.gz" -C "$T/e2e" e2e-1.0
  E2ESUM=$(sha256sum "$T/src/e2e-1.0.tar.gz" | awk '{print $1}')
  mkrec() {
    cat > "$T/rec/e2e-$1.kpkg" <<REC
PACKAGE=e2e
VERSION=$1
DESCRIPTION="End to end test package"
LICENSE="MIT"
SRC_URI="$T/src/e2e-1.0.tar.gz"
SHA256="$E2ESUM"
configure() {
  true
}
build() {
  true
}
install() {
  mkdir -p "\$DESTDIR/etc" "\$DESTDIR/usr/local/bin"
  printf '%s\n' "$2" > "\$DESTDIR/etc/kpkg-e2e.conf"
  printf '#!/bin/sh\necho e2e %s\n' "$1" > "\$DESTDIR/usr/local/bin/kpkg-e2e"
  chmod 755 "\$DESTDIR/usr/local/bin/kpkg-e2e"
}
REC
  }
  rm -f /etc/kpkg-e2e.conf /etc/kpkg-e2e.conf.kpkg-new /usr/local/bin/kpkg-e2e
  mkrec 1.0 factory-v1
  mkrec 1.1 factory-v2
  check e2e-install 0 "$(KPKG_FORCE=1 run install -y "$T/rec/e2e-1.0.kpkg")" "installed local/e2e-1.0"
  if [ -x /usr/local/bin/kpkg-e2e ] && grep -qx factory-v1 /etc/kpkg-e2e.conf; then printf 'PASS  e2e-files-installed\n'; pass=$((pass+1)); else printf 'FAIL  e2e-files-installed\n'; fail=$((fail+1)); fi
  check e2e-owns 0 "$(run owns /usr/local/bin/kpkg-e2e)" "e2e"
  printf 'mine\n' > /etc/kpkg-e2e.conf
  check e2e-upgrade 0 "$(KPKG_FORCE=1 run install -y "$T/rec/e2e-1.1.kpkg")" "installed local/e2e-1.1"
  if grep -q 'e2e 1.1' /usr/local/bin/kpkg-e2e; then printf 'PASS  e2e-binary-upgraded\n'; pass=$((pass+1)); else printf 'FAIL  e2e-binary-upgraded\n'; fail=$((fail+1)); fi
  if grep -qx mine /etc/kpkg-e2e.conf && grep -qx factory-v2 /etc/kpkg-e2e.conf.kpkg-new; then printf 'PASS  e2e-config-kept\n'; pass=$((pass+1)); else printf 'FAIL  e2e-config-kept\n'; fail=$((fail+1)); fi
  run hold e2e >/dev/null
  check e2e-held-not-downgraded 0 "$(KPKG_FORCE=1 run install -y "$T/rec/e2e-1.0.kpkg")" "is held at 1.1"
  if grep -q 'e2e 1.1' /usr/local/bin/kpkg-e2e; then printf 'PASS  e2e-hold-kept-version\n'; pass=$((pass+1)); else printf 'FAIL  e2e-hold-kept-version\n'; fail=$((fail+1)); fi
  run unhold e2e >/dev/null
  check e2e-remove 0 "$(KPKG_FORCE=1 run remove -y e2e)" "e2e"
  if [ ! -e /usr/local/bin/kpkg-e2e ]; then printf 'PASS  e2e-removed\n'; pass=$((pass+1)); else printf 'FAIL  e2e-removed\n'; fail=$((fail+1)); fi
  rm -f /etc/kpkg-e2e.conf /etc/kpkg-e2e.conf.kpkg-new /usr/local/bin/kpkg-e2e
fi

printf '\nkpkg tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
