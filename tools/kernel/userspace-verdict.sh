#!/bin/bash
set -uo pipefail
LOG=${1:-}
KREL=${2:-}
CVER=${3:-}
[ -s "$LOG" ] || { echo "::error::нет лога $LOG" >&2; exit 1; }
T=$(mktemp)
trap 'rm -f "$T"' EXIT
tr -d '\r\033' < "$LOG" > "$T"
f=0
err() { printf '::error::%s\n' "$*" >&2; f=1; }
grep -aq 'Kernel panic' "$T" && err "паника ядра"
grep -aqx 'KRYONK-START' "$T" || err "userspace не запустился"
grep -aqx 'KRYONK-DONE' "$T" || err "userspace не дошёл до конца проверок"
if [ -n "$KREL" ]; then
  grep -aqxF "KRYONK-UNAME: $KREL" "$T" || err "uname -r не $KREL"
fi
if [ -n "$CVER" ]; then
  grep -aqF "KRYONK-PROC: kryonk $CVER release" "$T" || err "/proc/kryonk не показывает kryonk $CVER"
fi
grep -aqx 'KRYONK-LOCKDOWN: none' "$T" && err "lockdown недоступен в ядре"
grep -a '^KRYONK-' "$T" | grep -aE 'BORE|LSM|LOCKDOWN|PROC' | sed 's/^/    /'
exit $f
