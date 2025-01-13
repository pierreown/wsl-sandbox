#!/bin/sh

WSLX_ZERO_PID_FILE=/var/run/wsl-init-zero.pid
WSLX_INIT_PID_FILE=''
WSLX_TIMES=0
while [ $WSLX_TIMES -lt 10 ]; do
    [ -n "$WSLX_ZERO_PID_FILE" ] && [ -f "$WSLX_ZERO_PID_FILE" ] && read -r WSLX_ZERO_PID _READ_ <"$WSLX_ZERO_PID_FILE" 2>/dev/null
    [ -n "$WSLX_ZERO_PID" ] && WSLX_INIT_PID_FILE="/proc/${WSLX_ZERO_PID}/task/${WSLX_ZERO_PID}/children"

    [ -n "$WSLX_INIT_PID_FILE" ] && [ -f "$WSLX_INIT_PID_FILE" ] && read -r WSLX_INIT_PID _READ_ <"$WSLX_INIT_PID_FILE" 2>/dev/null
    [ -n "$WSLX_INIT_PID" ] && [ -e "/proc/${WSLX_INIT_PID}" ] && break

    sleep .5

    WSLX_INIT_PID_FILE=''
    WSLX_TIMES=$((WSLX_TIMES + 1))
done

if [ -n "$WSLX_INIT_PID" ]; then
    : "${PWD:=$(pwd)}"
    exec /usr/bin/nsenter -m -i -p -w"$PWD" -t "$WSLX_INIT_PID" -- "${SHELL:-/bin/sh}"
fi
