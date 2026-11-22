#!/bin/bash
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
PUB=${PUB:-$(dirname "$HERE")/docs/kryonux.pub}

[ $# -ge 1 ] || { echo "usage: MINISIGN_KEY=file-or-key [MINISIGN_PASSWORD=...] $0 file..." >&2; exit 1; }
if [ -z "${MINISIGN_KEY:-}" ]; then
  echo "::warning::MINISIGN_KEY is not set, signing skipped" >&2
  exit 0
fi
command -v minisign >/dev/null || { echo "minisign is missing" >&2; exit 1; }

umask 077
K=$MINISIGN_KEY
if [ ! -f "$K" ]; then
  K=$(mktemp)
  trap 'rm -f "$K"' EXIT
  printf '%s\n' "$MINISIGN_KEY" | tr -d '\r' > "$K"
fi
grep -q '^untrusted comment:' "$K" || { echo "the signing key is not a minisign secret key file" >&2; exit 1; }

for f in "$@"; do
  [ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }
  rm -f "$f.minisig"
  if [ -n "${MINISIGN_PASSWORD:-}" ]; then
    printf '%s\n' "$MINISIGN_PASSWORD" | minisign -S -s "$K" -m "$f" -x "$f.minisig" -t "kryonux $(basename "$f")" >/dev/null
  else
    minisign -S -W -s "$K" -m "$f" -x "$f.minisig" -t "kryonux $(basename "$f")" >/dev/null
  fi
  [ -s "$f.minisig" ] || { echo "signature was not created for $f" >&2; exit 1; }
  if [ -f "$PUB" ]; then
    minisign -V -p "$PUB" -m "$f" -x "$f.minisig" >/dev/null || { echo "signature of $f does not match $PUB" >&2; exit 1; }
    echo "signed and verified: $f"
  else
    echo "signed: $f (no $PUB, verification skipped)"
  fi
done
