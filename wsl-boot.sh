#!/bin/sh
if [ -x /usr/local/wsl-sandbox/wsl-sandbox.sh ]; then
    export WSLX_ZERO_PID_FILE=/var/run/wsl-init-swapper.pid
    exec /usr/local/wsl-sandbox/wsl-sandbox.sh /sbin/init
fi
