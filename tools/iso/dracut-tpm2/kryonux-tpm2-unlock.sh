#!/bin/sh
. /lib/dracut-lib.sh

[ -e /tmp/kryonux-tpm2.done ] && exit 0
[ -c /dev/tpmrm0 ] || exit 0
[ -f /etc/kryonux/tpm2/seal.pub ] || exit 0

pcr=$(cat /etc/kryonux/tpm2/pcr 2>/dev/null || echo 7)
w=/tmp/kryonux-tpm2
mkdir -p "$w"

unseal() {
  tpm2_createprimary -C o -g sha256 -G ecc -c "$w/prim.ctx" -Q || return 1
  tpm2_startauthsession --policy-session -S "$w/sess.ctx" -Q || return 1
  tpm2_policypcr -S "$w/sess.ctx" -l "sha256:$pcr" -Q || return 1
  tpm2_load -C "$w/prim.ctx" -u /etc/kryonux/tpm2/seal.pub -r /etc/kryonux/tpm2/seal.priv -c "$w/key.ctx" -Q || return 1
  tpm2_unseal -c "$w/key.ctx" -p "session:$w/sess.ctx" -o "$w/key.bin" -Q || return 1
}

for u in $(getargs rd.luks.uuid=); do
  u=${u#luks-}
  dev=/dev/disk/by-uuid/$u
  [ -b "$dev" ] || continue
  [ -e "/dev/mapper/luks-$u" ] && continue
  if unseal && cryptsetup open --key-file "$w/key.bin" "$dev" "luks-$u"; then
    info "kryonux-tpm2: luks-$u открыт через tpm2"
    : > /tmp/kryonux-tpm2.done
  else
    warn "kryonux-tpm2: tpm2 ключ не подошёл, нужен пароль luks"
  fi
  tpm2_flushcontext -t -Q 2>/dev/null
  rm -f "$w"/*
done
exit 0
