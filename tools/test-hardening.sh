#!/bin/sh
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
R=$HERE/..
die() { printf 'fail: %s\n' "$*" >&2; exit 1; }
! grep -n 'popen(\|system(' "$R"/kpkg/*.c || die "kpkg: popen или system"
! grep -n '^[[:space:]]*eval ' "$R/kpkg/kpkg-box.sh" || die "kpkg-box.sh: eval"
grep -q 'KRYONK_VERIFY=${KRYONK_VERIFY:-1}' "$R/tools/mkiso.sh" || die "mkiso.sh: проверка подписи ядра должна быть включена по умолчанию"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
${CC:-cc} -std=gnu17 -O2 -Wall -Wextra -Wsign-conversion -Wformat=2 -Werror -fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=3 -o "$T/kpkg" "$R"/kpkg/*.c || die "kpkg.c не собирается с -Werror"
echo ok
grep -q "SECURITY_APPARMOR" "$R/tools/iso/mkiso-inside.sh" || die "mkiso-inside.sh: нет apparmor в ядре"
