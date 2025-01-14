#!/bin/sh

[ -x /usr/local/sandbox/sandbox.sh ] || exit 0

export SBOX_ENV_PID_FILE="/var/run/wsl-init-sandbox.pid"
export SBOX_ENV_NAME="wsl-init"
export SBOX_ENV_WORK_DIR="/"
export SBOX_ENV_HOLD_SYSINFO=1
exec /usr/local/sandbox/sandbox.sh /sbin/init >/var/log/wsl-init.log 2>&1
