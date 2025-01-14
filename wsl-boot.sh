#!/bin/sh

[ -x /usr/local/wsl-sandbox/wsl-sandbox.sh ] || exit 0

export SBOX_ENV_PID_FILE="/var/run/wsl-init-sandbox.pid"
export SBOX_ENV_NAME="wsl-init"
export SBOX_ENV_WORK_DIR="/"
exec /usr/local/wsl-sandbox/wsl-sandbox.sh /sbin/init >/var/log/wsl-init.log 2>&1
