#!/bin/bash

check() {
  require_binaries tpm2_unseal tpm2_load tpm2_startauthsession tpm2_policypcr tpm2_createprimary || return 1
  [ -f /etc/kryonux/tpm2/seal.pub ] || return 255
  return 0
}

depends() {
  echo crypt
  return 0
}

install() {
  inst_multiple tpm2_createprimary tpm2_startauthsession tpm2_policypcr tpm2_load tpm2_unseal tpm2_flushcontext cryptsetup
  inst_libdir_file "libtss2-tcti-device.so*" "libtss2-tcti-device.so.0*"
  inst_simple /etc/kryonux/tpm2/seal.pub /etc/kryonux/tpm2/seal.pub
  inst_simple /etc/kryonux/tpm2/seal.priv /etc/kryonux/tpm2/seal.priv
  inst_simple /etc/kryonux/tpm2/pcr /etc/kryonux/tpm2/pcr
  inst_hook initqueue/settled 10 "$moddir/kryonux-tpm2-unlock.sh"
}

installkernel() {
  instmods tpm_crb tpm_tis tpm_tis_core
  return 0
}
