#!/bin/bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
K=$HERE/kernel
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail() { printf 'тест не пройден: %s\n' "$*" >&2; exit 1; }
ok() { printf 'ok: %s\n' "$*"; }
command -v python3 >/dev/null || fail "нужен python3"

printf 'fake-busybox-binary' > "$T/bb"
python3 "$K/mkcpio.py" "$T/out.gz" "$T/bb" "$K/userspace-init.sh"
python3 - "$T/out.gz" "$K/userspace-init.sh" <<'EOP'
import gzip, sys
data = gzip.open(sys.argv[1]).read()
init = open(sys.argv[2], "rb").read()
pos = 0
seen = {}
while True:
    h = data[pos:pos + 110]
    assert h[:6] == b"070701", "magic"
    f = [int(h[6 + 8 * i:14 + 8 * i], 16) for i in range(13)]
    mode, size, rmaj, rmin, nsz = f[1], f[6], f[9], f[10], f[11]
    name = data[pos + 110:pos + 110 + nsz - 1].decode()
    assert data[pos + 110 + nsz - 1] == 0, "terminator"
    npos = pos + 110 + nsz
    npos += (4 - npos % 4) % 4
    body = data[npos:npos + size]
    pos = npos + size
    pos += (4 - pos % 4) % 4
    assert pos % 4 == 0
    if name == "TRAILER!!!":
        break
    seen[name] = (mode, body, rmaj, rmin)
assert pos == len(data), "хвост после trailer"
assert seen["init"][0] == 0o100755 and seen["init"][1] == init, "init"
assert seen["bin/busybox"][1] == b"fake-busybox-binary", "busybox"
assert seen["dev/console"][0] == 0o020600 and seen["dev/console"][2:] == (5, 1), "console"
assert seen["dev/null"][0] == 0o020666 and seen["dev/null"][2:] == (1, 3), "null"
for d in ("bin", "dev", "proc", "sys", "tmp"):
    assert seen[d][0] == 0o040755, d
EOP
ok "initramfs: формат newc, init, busybox, узлы console и null"

sh -n "$K/userspace-init.sh" || fail "userspace-init.sh с ошибкой синтаксиса"
for m in KRYONK-START KRYONK-UNAME KRYONK-PROC KRYONK-BORE KRYONK-LOCKDOWN KRYONK-LSM KRYONK-DONE; do
  grep -q "$m" "$K/userspace-init.sh" || fail "в init нет $m"
done
ok "init печатает все маркеры"

good() {
  printf 'boot noise\r\nKRYONK-START\r\nKRYONK-UNAME: 6.18.10-kryonk-0.4\r\nKRYONK-PROC: kryonk 0.4 release 6.18.10-kryonk-0.4 \r\nKRYONK-BORE: 1\r\nKRYONK-LOCKDOWN: none [integrity] confidentiality\r\nKRYONK-LSM: lockdown,capability,landlock,yama,apparmor,bpf\r\nKRYONK-DONE\r\n'
}
good > "$T/good.log"
bash "$K/userspace-verdict.sh" "$T/good.log" 6.18.10-kryonk-0.4 0.4 >/dev/null 2>&1 || fail "хороший лог отвергнут"
ok "хороший лог принят"

try() {
  local name=$1 filter=$2 krel=${3:-6.18.10-kryonk-0.4} cver=${4:-0.4}
  good | eval "$filter" > "$T/bad.log"
  if bash "$K/userspace-verdict.sh" "$T/bad.log" "$krel" "$cver" >/dev/null 2>&1; then fail "принят лог: $name"; fi
}
try "нет DONE" "grep -v KRYONK-DONE"
try "нет START" "grep -v KRYONK-START"
try "чужой uname" "cat" 6.18.9-kryonk-0.4
try "чужая версия kryonk" "cat" 6.18.10-kryonk-0.4 0.3
try "нет lockdown" "sed 's/^KRYONK-LOCKDOWN: .*/KRYONK-LOCKDOWN: none\r/'"
try "паника" "cat; printf 'Kernel panic - not syncing\r\n'"
try "нет /proc/kryonk" "sed 's/^KRYONK-PROC: .*/KRYONK-PROC: \r/'"
if bash "$K/userspace-verdict.sh" "$T/nonexistent.log" >/dev/null 2>&1; then fail "принят отсутствующий лог"; fi
ok "плохие логи отвергаются: нет done, start, чужие версии, lockdown, паника, /proc/kryonk"

echo "все тесты пройдены"
