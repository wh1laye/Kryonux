#!/bin/bash
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$HERE")
STAGE3=
ISO=
KERNEL=
RECIPES=${RECIPES_DIR:-}
BOOT=0
pass=0
fail=0
skip=0

usage() {
  echo "usage: bash tools/test-all.sh [--stage3 archive.tar.xz] [--iso file.iso] [--kernel vmlinuz] [--recipes dir] [--boot]"
  echo "without arguments the static checks run: scripts, C code, kpkg, site, security, configs"
  echo "--stage3 checks the stage 3 archive, --iso checks the ISO, --boot also boots it in QEMU,"
  echo "--kernel boots the kernel in QEMU, --recipes checks the kpkg-recipes tree"
}

while [ $# -gt 0 ]; do
  case $1 in
    --stage3) STAGE3=${2:-}; shift ;;
    --iso) ISO=${2:-}; shift ;;
    --kernel) KERNEL=${2:-}; shift ;;
    --recipes) RECIPES=${2:-}; shift ;;
    --boot) BOOT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
  shift
done

ok() { printf 'PASS  %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL  %s\n' "$1"; fail=$((fail+1)); }
warn() { printf 'WARN  %s\n' "$1"; }
skp() { printf 'SKIP  %s\n' "$1"; skip=$((skip+1)); }
section() { printf '\n==> %s\n' "$1"; }
run() {
  local name=$1; shift
  if "$@" > "$TMP/last.log" 2>&1; then ok "$name"; else bad "$name"; tail -15 "$TMP/last.log" | sed 's/^/      /'; fi
}
need() { command -v "$1" >/dev/null 2>&1; }

TMP=$(mktemp -d /var/tmp/kryonux-test-all.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
cd "$REPO"

section "shell scripts"
while IFS= read -r f; do
  run "bash -n ${f#"$REPO"/}" bash -n "$f"
done < <(find tools kpkg -type f \( -name '*.sh' -o -name 'kryonux-*' -o -name 'init' \) ! -name '*.md' ! -name '*.py' ! -name '*.conf' ! -name '*.sql' | sort | sed "s#^#$REPO/#")
if need shellcheck; then
  while IFS= read -r f; do
    run "shellcheck ${f#"$REPO"/}" shellcheck -x "$f"
  done < <(find tools kpkg -type f -name '*.sh' | sort | sed "s#^#$REPO/#")
else
  skp "shellcheck is not installed"
fi

section "C code (kpkg)"
run "build with -Werror" make -C kpkg clean all
run "gcc -fanalyzer finds no double free or use after free" bash -c "for f in kpkg/*.c; do gcc -std=gnu17 -O2 -fanalyzer -c \$f -o /dev/null 2>&1 | grep -E 'Wanalyzer-(double-free|use-after-free|null-deref|out-of-bounds)' && exit 1; done; exit 0"
run "no popen or system, no unsafe string calls" bash -c "! grep -nE '\\b(popen|system|gets|sprintf|strcpy|strcat)\\(' kpkg/*.c | grep -v 'sums\\[\\|strcat(sums'"
run "sanitizer build passes the kpkg tests" env ASAN_OPTIONS=detect_leaks=0 KPKG_TEST_CFLAGS="-fsanitize=address,undefined -fno-sanitize-recover=undefined -g" bash tools/test-kpkg.sh
make -C kpkg clean > /dev/null 2>&1

section "kpkg"
run "kpkg tests" bash tools/test-kpkg.sh
run "update signature check" bash tools/test-update-sign.sh
run "hardening script" sh tools/test-hardening.sh
run "config.kpkg ships empty" bash -c "[ -f kpkg/etc/kpkg/config.kpkg ] && [ ! -s kpkg/etc/kpkg/config.kpkg ]"
run "kpkg public key equals the site key" cmp kpkg/etc/kpkg/kryonux.pub docs/kryonux.pub
make -C kpkg > /dev/null 2>&1
if [ -n "$RECIPES" ] && [ -d "$RECIPES" ]; then
  run "recipe tree: kpkg check" bash -c "kpkg/kpkg check '$RECIPES' 2>&1 | grep -v 'SHA256 is missing' | grep -E 'unknown category|has no recipe|must use https|checksums|invalid|unknown header' && exit 1 || exit 0"
  run "recipe tree: test-recipes.sh" env KRYONUX_DIR="$REPO" KPKG="$REPO/kpkg/kpkg" bash "$RECIPES/tools/test-recipes.sh"
  run "fastfetch config in recipes equals stage 3 config" cmp "$RECIPES/tools/fastfetch/fastfetch-2.70.0/files/config.jsonc" tools/stage3/fastfetch.jsonc
else
  skp "recipe tree not given (--recipes DIR)"
fi

section "security rules"
run "no unsigned or insecure switches" bash -c "! grep -rnE -- '--unsigned|--insecure|KPKG_STRICT|SKIP_CHECKSUM' kpkg tools .github --include=* 2>/dev/null | grep -v 'test-all.sh\\|test-kpkg.sh\\|CHANGELOG'"
run "no curl piped into a shell in stage 3 or setup scripts" bash -c "! grep -nE 'curl[^|]*\\|[[:space:]]*(ba)?sh' tools/stage3/* kpkg/kpkg-setup.sh"
run "stage 3 sshd has no root login and no passwords" bash -c "grep -qx 'PermitRootLogin no' tools/stage3/sshd-kryonux.conf && grep -qx 'PasswordAuthentication no' tools/stage3/sshd-kryonux.conf"
run "sysctl hardening keys present" bash -c "for k in kernel.kptr_restrict kernel.dmesg_restrict kernel.yama.ptrace_scope fs.protected_symlinks fs.suid_dumpable net.ipv4.tcp_syncookies kernel.kexec_load_disabled kernel.unprivileged_bpf_disabled; do grep -q \"^\$k\" tools/stage3/sysctl-kryonux.conf || { echo missing \$k; exit 1; }; done"
run "firewall default policy is drop" bash -c "grep -q 'policy drop' tools/stage3/nftables.conf"
run "modprobe blocks rare network and DMA modules" bash -c "for m in dccp sctp firewire-core cramfs; do grep -q \"install \$m /bin/false\" tools/stage3/modprobe-kryonux.conf || exit 1; done"
if grep -hE 'uses: [^@]+@(v?[0-9]+|main|master)[[:space:]]*$' .github/workflows/*.yml > "$TMP/unpinned.txt"; then warn "workflow actions are not pinned to a commit, run tools/pin-actions.sh ($(wc -l < "$TMP/unpinned.txt") places)"; else ok "workflow actions are pinned"; fi
run "no old project names" bash -c "! grep -rniE 'kryounix|cloudk|cloudpkg|cloudos' kpkg tools AGENTS.md README.md --include=* 2>/dev/null | grep -v 'test-all.sh\\|CHANGELOG\\|test-recipes\\|test-iso.sh\\|AGENTS.md'"
run "no source comments in kpkg C files" bash -c "! grep -nE '^[[:space:]]*(//|/\\*)' kpkg/*.c kpkg/*.h"

section "fastfetch"
run "config is valid JSON" python3 -c "import json,re;json.loads(re.sub(r'^\\s*//.*\$','',open('tools/stage3/fastfetch.jsonc').read(),flags=re.M))"
run "logo is the K in blue shades" bash -c "grep -q '████      ████' tools/stage3/fastfetch.jsonc && grep -q '38;5;39' tools/stage3/fastfetch.jsonc"
run "stage 3 keeps fastfetch held" bash -c "grep -q \"kpkg/hold\" tools/stage3/build-inside.sh && grep -q fastfetch tools/stage3/build-inside.sh"

section "website"
run "site structure" node tools/test-site.js
while IFS= read -r f; do run "node --check ${f#"$REPO"/}" node --check "$f"; done < <(find docs -name '*.js' | sort | sed "s#^#$REPO/#")
run "404 page is English only" bash -c "grep -q '<html lang=\"en\"' docs/404.html && ! grep -qP '[А-Яа-яЁё]' docs/404.html && ! grep -q 'theme.js\\|typo.js\\|localStorage.getItem(.lang' docs/404.html"
run "sitemap lists both domains" bash -c "grep -q 'wh1laye.github.io/Kryonux' docs/sitemap.xml && grep -q 'kryonux.pages.dev' docs/sitemap.xml"

section "stage 3"
run "stage 3 gate (repository)" bash tools/test-stage3-gate.sh
run "stage 3 firewall" bash -c "if [ \$(id -u) = 0 ] && command -v nft >/dev/null; then bash tools/test-firewall.sh; else echo skipped; fi"
if [ -n "$STAGE3" ]; then
  run "stage 3 gate (archive)" bash tools/test-stage3-gate.sh "$STAGE3"
  if [ -f "$STAGE3.sha256" ]; then run "stage 3 sha256" bash -c "cd \"\$(dirname '$STAGE3')\" && sha256sum -c \"\$(basename '$STAGE3').sha256\""; fi
  if [ -f "$STAGE3.minisig" ] && need minisign; then run "stage 3 minisign" minisign -V -p docs/kryonux.pub -m "$STAGE3" -x "$STAGE3.minisig"; fi
  run "stage 3 contains no failed package report" bash -c "! tar -tf '$STAGE3' | grep -q 'kryonux-report'"
  run "stage 3 holds fastfetch and ships the K config" bash -c "tar -xOf '$STAGE3' ./etc/kpkg/hold 2>/dev/null | grep -qx fastfetch && tar -tf '$STAGE3' | grep -q 'etc/xdg/fastfetch/config.jsonc'"
else
  skp "stage 3 archive not given (--stage3 FILE)"
fi

section "ISO"
run "ISO scripts (static)" bash tools/test-iso.sh
if [ -n "$ISO" ]; then
  run "ISO file is not empty" test -s "$ISO"
  if [ -f "$ISO.sha256" ]; then run "ISO sha256" bash -c "cd \"\$(dirname '$ISO')\" && sha256sum -c \"\$(basename '$ISO').sha256\""; fi
  if [ -f "$ISO.minisig" ] && need minisign; then run "ISO minisign" minisign -V -p docs/kryonux.pub -m "$ISO" -x "$ISO.minisig"; fi
  if [ "$BOOT" = 1 ]; then
    if need qemu-system-x86_64; then
      run "ISO boots to the live system" bash -c "timeout 240 qemu-system-x86_64 -m 2048 -smp 2 -display none -serial file:'$TMP/iso.serial' -no-reboot -cdrom '$ISO' $([ -w /dev/kvm ] && echo -enable-kvm) >/dev/null 2>&1; grep -qiE 'kryonux|login:' '$TMP/iso.serial'"
    else
      bad "qemu-system-x86_64 is missing, cannot boot the ISO"
    fi
  else
    skp "ISO boot test (add --boot)"
  fi
else
  skp "ISO not given (--iso FILE)"
fi

section "kernel"
run "kernel patch series" bash -c "if [ -f tools/test-kernel-patches.sh ] && [ -n \"\${KERNEL_SRC:-}\" ]; then bash tools/test-kernel-patches.sh; else echo skipped; fi"
run "kernel userspace helpers" bash tools/test-kernel-userspace.sh
if [ -n "$KERNEL" ]; then
  if need qemu-system-x86_64; then run "kernel boots in QEMU" bash tools/kernel/boot-check.sh "$KERNEL"; else bad "qemu-system-x86_64 is missing, cannot boot the kernel"; fi
else
  skp "kernel image not given (--kernel vmlinuz)"
fi

printf '\nall tests: %d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" = 0 ]
