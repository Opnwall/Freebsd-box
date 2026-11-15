#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
source build.env
export GOOS=freebsd GOARCH=amd64 GOAMD64=v1 CGO_ENABLED=0
mkdir -p dist
cd .build/sing-box
go build -trimpath -tags "$BUILD_TAGS" -ldflags "-X github.com/sagernet/sing-box/constant.Version=${SING_BOX_VERSION}-freebsd -s -w -buildid=" -o "$ROOT/dist/bsd-box-freebsd-amd64" ./cmd/sing-box
cd "$ROOT/dist"
xz -T0 -9 -k -f bsd-box-freebsd-amd64
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum bsd-box-freebsd-amd64.xz > SHA256SUMS
else
  shasum -a 256 bsd-box-freebsd-amd64.xz > SHA256SUMS
fi
{
  echo "sing-box: $SING_BOX_VERSION"
  echo "sing-tun: $(cat "$ROOT/.build/sing-tun-version")"
  echo "target: $GOOS/$GOARCH ($GOAMD64), CGO_ENABLED=$CGO_ENABLED"
  echo "tags: $BUILD_TAGS"
  go version
  go version -m bsd-box-freebsd-amd64
} > build-info.txt
