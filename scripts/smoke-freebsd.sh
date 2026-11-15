#!/bin/sh
set -eu
[ "$(uname -s)" = FreeBSD ]
[ "$(uname -m)" = amd64 ]
cd "$(dirname "$0")/.."
xz -dkf dist/bsd-box-freebsd-amd64.xz
chmod +x dist/bsd-box-freebsd-amd64
binary="$PWD/dist/bsd-box-freebsd-amd64"
"$binary" version
pid=
cleanup() {
  if [ -n "$pid" ]; then
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" || true
  fi
}
trap cleanup EXIT INT TERM
for stack in system gvisor mixed; do
  cat > dist/smoke.json <<EOF
{
  "log": {"level": "debug"},
  "inbounds": [{"type": "tun", "interface_name": "tun9", "address": ["172.19.0.1/30"], "mtu": 1500, "auto_route": false, "dns_mode": "disabled", "stack": "$stack"}],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
EOF
  "$binary" check -c dist/smoke.json
  "$binary" run -c dist/smoke.json > "dist/smoke-$stack.log" 2>&1 &
  pid=$!
  sleep 3
  if ! kill -0 "$pid" 2>/dev/null; then
    cat "dist/smoke-$stack.log"
    exit 1
  fi
  ifconfig tun9
  grep -q 'sing-box started' "dist/smoke-$stack.log"
  kill -TERM "$pid"
  wait "$pid"
  pid=
  if ifconfig tun9 >/dev/null 2>&1; then
    echo "TUN device was not cleaned up for $stack" >&2
    exit 1
  fi
  echo "TUN $stack startup and cleanup passed"
done
