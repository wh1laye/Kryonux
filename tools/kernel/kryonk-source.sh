KRYONK_SRC_MISS=""

kryonk_edit() {
  local file=$1 expr=$2 check=$3
  if [ ! -f "$file" ]; then KRYONK_SRC_MISS="$KRYONK_SRC_MISS $file"; return 0; fi
  sed -E -i "$expr" "$file"
  grep -Eq "$check" "$file" || KRYONK_SRC_MISS="$KRYONK_SRC_MISS $file"
  return 0
}

kryonk_source() {
  local ov=$HERE/overlay d=security/kryonk
  [ -d "$ov/$d" ] || die "нет $ov/$d"
  [ -f security/Kconfig ] && [ -f security/Makefile ] || die "в дереве ядра нет security/Kconfig или security/Makefile"
  mkdir -p "$d"
  cp "$ov/$d"/Kconfig "$ov/$d"/Makefile "$ov/$d"/kryonk.c "$d"/
  printf '#define KRYONK_VERSION "%s"\n' "$KRYONK_VER" > "$d/kryonk_version.h"
  grep -q 'security/kryonk/Kconfig' security/Kconfig || printf '\nsource "security/kryonk/Kconfig"\n' >> security/Kconfig
  grep -q 'CONFIG_SECURITY_KRYONK' security/Makefile || printf '\nobj-$(CONFIG_SECURITY_KRYONK)\t+= kryonk/\n' >> security/Makefile
  grep -q 'kryonk/Kconfig' security/Kconfig && grep -q 'CONFIG_SECURITY_KRYONK' security/Makefile || die "слой kryonk не подключился к security"

  kryonk_edit lib/vsprintf.c 's/^(int kptr_restrict __read_mostly)[[:space:]]*;/\1 = 2;/' '^int kptr_restrict __read_mostly = 2;'
  kryonk_edit mm/page-writeback.c 's/^((static )?int vm_dirty_ratio[[:space:]]*=[[:space:]]*)[0-9]+;/\1 15;/' 'vm_dirty_ratio[[:space:]]*=[[:space:]]*15;'
  kryonk_edit mm/page-writeback.c 's/^((static )?int dirty_background_ratio[[:space:]]*=[[:space:]]*)[0-9]+;/\1 5;/' 'dirty_background_ratio[[:space:]]*=[[:space:]]*5;'
  kryonk_edit mm/vmscan.c 's/^(int vm_swappiness[[:space:]]*=[[:space:]]*)[0-9]+;/\1 100;/' 'vm_swappiness[[:space:]]*=[[:space:]]*100;'
  say "слой kryonk $KRYONK_VER подключён"
}
