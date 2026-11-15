#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
source build.env
[[ "$SING_BOX_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
mkdir -p .build
if [[ -e .build/sing-box || -e .build/sing-tun ]]; then
  echo 'Sources already exist; remove .build before preparing again.' >&2
  exit 1
fi
curl --fail --location --retry 3 "https://github.com/SagerNet/sing-box/archive/refs/tags/v${SING_BOX_VERSION}.tar.gz" -o .build/sing-box.tar.gz
tar -xzf .build/sing-box.tar.gz -C .build
mv ".build/sing-box-${SING_BOX_VERSION}" .build/sing-box
cd .build/sing-box
# Resolve the exact go.mod dependency, including pseudo-versions, through Go.
TUN_VERSION=$(go mod edit -json | jq -er '.Require[] | select(.Path == "github.com/sagernet/sing-tun") | .Version')
TUN_DIR=$(go mod download -json "github.com/sagernet/sing-tun@${TUN_VERSION}" | jq -er '.Dir')
cp -R "$TUN_DIR" ../sing-tun
chmod -R u+w ../sing-tun
python3 "$ROOT/scripts/migrate-patch.py" --source "$ROOT/.build/sing-box" --patch "$ROOT/patches/sing-box-freebsd.patch" --baseline "$ROOT/patches/bases/core" --component core --version "$SING_BOX_VERSION" --output "$ROOT/.build/patch-update"
python3 "$ROOT/scripts/migrate-patch.py" --source "$ROOT/.build/sing-tun" --patch "$ROOT/patches/sing-tun-freebsd.patch" --baseline "$ROOT/patches/bases/sing-tun" --component sing-tun --version "$TUN_VERSION" --output "$ROOT/.build/patch-update"
cd ../sing-box
go mod edit -replace github.com/sagernet/sing-tun=../sing-tun
printf '%s\n' "$TUN_VERSION" > ../sing-tun-version
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  if [[ -f "$ROOT/.build/patch-update/migrated" ]]; then
    echo 'migrated=true' >> "$GITHUB_OUTPUT"
  else
    echo 'migrated=false' >> "$GITHUB_OUTPUT"
  fi
fi
