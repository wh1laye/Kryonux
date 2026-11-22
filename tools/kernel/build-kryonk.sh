#!/bin/bash
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$(dirname "$HERE")")
KVER=${KVER:-}
KRYONK_VER=${KRYONK_VER:-0.0.1}
MARCH=${MARCH:-x86-64-v3}
WORK=${WORK:-/var/tmp/kryonk-build}
OUT=${OUT:-$PWD}
JOBS=${JOBS:-$(nproc)}
KERNEL_SRC=${KERNEL_SRC:-}
MINISIGN_KEY=${MINISIGN_KEY:-}
PUB=${PUB:-$REPO/docs/kryonux.pub}
PIN=${PIN:-$HERE/kernel-pin.txt}
STRICT=${STRICT:-0}
CK=kryonk-$KRYONK_VER-$MARCH

say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

case $MARCH in x86-64|x86-64-v2|x86-64-v3|x86-64-v4) ;; *) die "MARCH: x86-64, x86-64-v2, x86-64-v3 or x86-64-v4" ;; esac
case $WORK in /|/usr*|/etc*|/home|/root|/var|/boot) die "unsafe work directory: $WORK" ;; esac
[ "$(uname -m)" = x86_64 ] || die "x86_64 is required"
for c in gcc make curl tar xz zstd patch gpg perl awk sha256sum flex bison bc find; do
  command -v "$c" >/dev/null || die "missing command: $c"
done
[ -f "$HERE/kryonk.config" ] || die "no $HERE/kryonk.config"

mkdir -p "$WORK" "$OUT"
fetch() { curl -fL --proto =https --retry 5 --retry-delay 10 --connect-timeout 20 -sS -o "$2" "$1"; }

. "$HERE/lib.sh"

if [ -n "$KERNEL_SRC" ]; then
  [ -e "$KERNEL_SRC" ] || die "no such source: $KERNEL_SRC"
  SRCDIR=$KERNEL_SRC
  TARBALL=$KERNEL_SRC
  say "local kernel source: $KERNEL_SRC"
else
  if [ -z "$KVER" ]; then
    say "resolving the latest $KERNEL_SERIES kernel"
    KVER=$(kernel_latest "$WORK/index.html") || die "cannot read the kernel.org index"
    [ -n "$KVER" ] || die "cannot detect the latest $KERNEL_SERIES kernel, set KVER"
  fi
  say "kernel $KVER"
  kernel_get "$KVER" "$WORK"
  TARBALL=$WORK/linux-$KVER.tar.xz
  SUM=$(sha256sum "$TARBALL" | awk '{print $1}')
  if [ -f "$PIN" ] && WANT=$(awk -v v="$KVER" '$1==v{print $2}' "$PIN") && [ -n "$WANT" ]; then
    [ "$SUM" = "$WANT" ] || die "sha256 mismatch for linux-$KVER"
    if [ -f "$PIN.minisig" ] && command -v minisign >/dev/null 2>&1 && [ -f "$PUB" ]; then
      minisign -V -q -p "$PUB" -m "$PIN" -x "$PIN.minisig" || die "kernel pin signature mismatch"
      say "kernel pin verified with the Kryonux key"
    elif [ "$STRICT" = 1 ]; then
      die "STRICT=1 requires a signed kernel pin"
    fi
  elif [ "$STRICT" = 1 ]; then
    die "STRICT=1 requires linux-$KVER to be pinned in $PIN (tools/kernel/pin-kernel.sh)"
  else
    say "linux-$KVER is not pinned, sha256 $SUM"
  fi
  SRCDIR=$WORK/src
fi

if [ ! -d "$SRCDIR" ]; then
  say "unpacking the source"
  rm -rf "$WORK/unpack"
  mkdir -p "$WORK/unpack"
  tar -xf "$TARBALL" -C "$WORK/unpack"
  SRCDIR=$(find "$WORK/unpack" -maxdepth 1 -mindepth 1 -type d | head -1)
  [ -n "$SRCDIR" ] || die "the archive has no source directory"
fi
[ -f "$SRCDIR/Makefile" ] || die "no kernel Makefile in $SRCDIR"
cd "$SRCDIR"
ours=0
if [ -f "$HERE/patches/series" ]; then
  while read -r name; do
    case $name in ''|\#*) continue ;; esac
    [ -f "$HERE/patches/$name" ] || die "the series lists a missing patch: $name"
    patch -p1 --forward --batch -N < "$HERE/patches/$name" > "$WORK/ours.log" 2>&1 || { tail -20 "$WORK/ours.log" >&2; die "Kryonux patch failed: $name"; }
    ours=$((ours+1))
  done < "$HERE/patches/series"
fi
say "Kryonux patches applied: $ours"
(
  HERE=$(dirname "$HERE")
  . "$HERE/kernel/kryonk-source.sh"
  kryonk_source
)

say "config: x86_64_defconfig + kryonk.config ($MARCH)"
make x86_64_defconfig
FRAG=$WORK/kryonk-frag.config
cat "$HERE/kryonk.config" > "$FRAG"
printf 'CONFIG_MODULES=y\nCONFIG_MODULE_UNLOAD=y\n' >> "$FRAG"
./scripts/kconfig/merge_config.sh -m .config "$FRAG"
make olddefconfig
scripts/config --set-str CONFIG_LOCALVERSION "-kryonk-$KRYONK_VER"
make olddefconfig
grep -q '^CONFIG_MODULES=y' .config || die "CONFIG_MODULES is not enabled after olddefconfig"
grep -E '^(CONFIG_LOCALVERSION|CONFIG_MODULES)=' .config || true
KREL=$(make -s kernelrelease)
say "kernel release: $KREL"

say "building with $JOBS jobs"
KCF=""; [ "$MARCH" = x86-64 ] || KCF="-march=$MARCH"
make -j"$JOBS" KCFLAGS="$KCF" bzImage modules

say "staging modules"
rm -rf "$WORK/modules"
mkdir -p "$WORK/modules"
make modules_install INSTALL_MOD_PATH="$WORK/modules" INSTALL_MOD_STRIP=1
MODDIR=$(find "$WORK/modules" -maxdepth 3 -mindepth 1 -type d -path '*/lib/modules/*' | head -1)
if [ -z "$MODDIR" ]; then
  find "$WORK/modules" -maxdepth 4 >&2 || true
  die "modules_install produced no module directory"
fi
MODREL=$(basename "$MODDIR")
say "modules staged: $MODREL"

say "artifacts"
cp arch/x86/boot/bzImage "$OUT/$CK-vmlinuz"
tar -C "$(dirname "$MODDIR")" -cf - "$MODREL" | zstd -T0 -19 -q -o "$OUT/$CK-modules.tar.zst"
cp .config "$OUT/$CK-config"
printf '%s\n' "$MODREL" > "$OUT/$CK-krel.txt"
( cd "$OUT" && sha256sum "$CK-vmlinuz" "$CK-modules.tar.zst" "$CK-config" "$CK-krel.txt" > "$CK.sha256" )

if [ -n "$MINISIGN_KEY" ]; then
  MINISIGN_KEY="$MINISIGN_KEY" MINISIGN_PASSWORD="${MINISIGN_PASSWORD:-}" bash "$REPO/tools/sign.sh" "$OUT/$CK.sha256"
  say "signed with the Kryonux key: $CK.sha256.minisig"
else
  say "MINISIGN_KEY is not set, artifacts are unsigned"
fi

say "done: $OUT/$CK-vmlinuz"
( cd "$OUT" && cat "$CK.sha256" )
