#!/usr/bin/env bash
set -euo pipefail

if [ -d /workspace/kismet-base/config/skel ]; then
  mkdir -p /root
  cp -a /workspace/kismet-base/config/skel/. /root/
fi

if [ -f /workspace/kismet-base/config/usr/local/lib/kismet/kismet-firstboot-wizard ]; then
  install -Dm755 /workspace/kismet-base/config/usr/local/lib/kismet/kismet-firstboot-wizard /usr/local/bin/kismet-firstboot-wizard
fi

exec /startup.sh
