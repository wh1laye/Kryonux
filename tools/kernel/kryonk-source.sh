KRYONK_SRC_MISS=""

kryonk_edit() {
  local file=$1 expr=$2 check=$3
  if [ ! -f "$file" ]; then KRYONK_SRC_MISS="$KRYONK_SRC_MISS $file"; return 0; fi
  sed -E -i "$expr" "$file"
  grep -Eq "$check" "$file" || KRYONK_SRC_MISS="$KRYONK_SRC_MISS $file"
  return 0
}

kryonk_source() {
  local d=security/kryonk
  [ -f security/Kconfig ] && [ -f security/Makefile ] || die "the kernel tree has no security/Kconfig or security/Makefile"
  [ -f "$d/kryonk.c" ] || die "the kryonk patch series is not applied"
  printf '#define KRYONK_VERSION "%s"\n' "$KRYONK_VER" > "$d/kryonk_version.h"
  grep -q 'security/kryonk/Kconfig' security/Kconfig || printf '\nsource "security/kryonk/Kconfig"\n' >> security/Kconfig
  grep -q 'CONFIG_SECURITY_KRYONK' security/Makefile || printf '\nobj-$(CONFIG_SECURITY_KRYONK)\t+= kryonk/\n' >> security/Makefile
  grep -q 'kryonk/Kconfig' security/Kconfig && grep -q 'CONFIG_SECURITY_KRYONK' security/Makefile || die "the kryonk layer is not wired into security"
  kryonk_edit lib/vsprintf.c 's/^(int kptr_restrict __read_mostly)[[:space:]]*;/\1 = 2;/' '^int kptr_restrict __read_mostly = 2;'
  kryonk_edit mm/page-writeback.c 's/^((static )?int vm_dirty_ratio[[:space:]]*=[[:space:]]*)[0-9]+;/\1 15;/' 'vm_dirty_ratio[[:space:]]*=[[:space:]]*15;'
  kryonk_edit mm/page-writeback.c 's/^((static )?int dirty_background_ratio[[:space:]]*=[[:space:]]*)[0-9]+;/\1 5;/' 'dirty_background_ratio[[:space:]]*=[[:space:]]*5;'
  kryonk_edit mm/vmscan.c 's/^(int vm_swappiness[[:space:]]*=[[:space:]]*)[0-9]+;/\1 100;/' 'vm_swappiness[[:space:]]*=[[:space:]]*100;'
  if [ -n "$KRYONK_SRC_MISS" ] && [ "${STRICT:-0}" = 1 ]; then
    die "kryonk default edits did not apply to:$KRYONK_SRC_MISS"
  fi
  [ -z "$KRYONK_SRC_MISS" ] || printf 'warning: kryonk default edits did not apply to:%s\n' "$KRYONK_SRC_MISS" >&2
  say "kryonk $KRYONK_VER wired into the tree"
}
