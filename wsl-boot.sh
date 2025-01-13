#!/bin/bash

if [ -x /usr/local/wsl-sandbox/wsl-sandbox.sh ]; then
    export WSLX_ZERO_PID_FILE=/var/run/wsl-init-zero.pid
    export WSLX_NAME=wsl-init
    export WSLX_WORK_DIR=/
    exec /usr/local/wsl-sandbox/wsl-sandbox.sh /sbin/init >/var/log/wsl-init.log 2>&1
fi
