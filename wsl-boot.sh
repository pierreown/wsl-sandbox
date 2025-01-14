#!/bin/sh

SBOX_ZERO_PID_FILE="/var/run/wsl-init-sandbox.pid"

echo "$$" >"$SBOX_ZERO_PID_FILE"
exec unshare --fork --pid --mount-proc -- /sbin/init
