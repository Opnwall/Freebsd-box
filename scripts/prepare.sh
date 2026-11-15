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
patch --batch --fuzz=0 -p1 < "$ROOT/patches/sing-box-freebsd.patch"
cd ../sing-tun
patch --batch --fuzz=0 -p1 < "$ROOT/patches/sing-tun-freebsd.patch"
cd ../sing-box
go mod edit -replace github.com/sagernet/sing-tun=../sing-tun
printf '%s\n' "$TUN_VERSION" > ../sing-tun-version
