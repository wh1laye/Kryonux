KERNEL_SERIES=${KERNEL_SERIES:-6.18}
KERNEL_BASE=${KERNEL_BASE:-https://cdn.kernel.org/pub/linux/kernel}
KERNEL_KEYS=${KERNEL_KEYS:-torvalds@kernel.org gregkh@kernel.org}

kernel_fetch() {
  curl -fL --proto =https --retry 5 --retry-delay 10 --connect-timeout 20 -sS -o "$2" "$1"
}

kernel_latest() {
  local major=${KERNEL_SERIES%%.*} page=$1
  kernel_fetch "$KERNEL_BASE/v$major.x/" "$page" || return 1
  grep -oE "linux-${KERNEL_SERIES//./\\.}\.[0-9]+\.tar\.xz" "$page" | sed -E 's/^linux-//; s/\.tar\.xz$//' | sort -V | tail -1
}

kernel_pgp() {
  local tarball=$1 sign=$2 home
  command -v gpg >/dev/null || return 2
  home=$(mktemp -d)
  if ! GNUPGHOME=$home gpg --batch --quiet --auto-key-locate clear,wkd --locate-keys $KERNEL_KEYS >/dev/null 2>&1; then
    rm -rf "$home"
    return 1
  fi
  xz -dc "$tarball" | GNUPGHOME=$home gpg --batch --verify "$sign" - >/dev/null 2>&1
  local rc=$?
  rm -rf "$home"
  return $rc
}

kernel_get() {
  local ver=$1 dir=$2 major=${1%%.*}
  kernel_fetch "$KERNEL_BASE/v$major.x/linux-$ver.tar.xz" "$dir/linux-$ver.tar.xz" || die "download failed: linux-$ver.tar.xz"
  kernel_fetch "$KERNEL_BASE/v$major.x/linux-$ver.tar.sign" "$dir/linux-$ver.tar.sign" || die "download failed: linux-$ver.tar.sign"
  kernel_pgp "$dir/linux-$ver.tar.xz" "$dir/linux-$ver.tar.sign" || die "the kernel.org PGP signature of linux-$ver does not verify"
  say "kernel.org PGP signature verified for linux-$ver"
}
