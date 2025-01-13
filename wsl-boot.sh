#!/bin/sh
if [ -x /usr/local/bin/wsl-sandbox.sh ]; then
    export WSLX_ZERO_PID_FILE=/var/run/wsl-init-swapper.pid
    exec /usr/local/bin/wsl-sandbox.sh /sbin/init
fi
