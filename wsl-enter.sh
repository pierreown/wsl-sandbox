#!/bin/sh

WSLX_ZERO_PID_FILE=/var/run/wsl-init-zero.pid
WSLX_TIMES=0

# Maximum 20 times of attempts
while [ $WSLX_TIMES -lt 20 ]; do
    WSLX_ZERO_PID=''
    WSLX_INIT_PID_FILE='' WSLX_INIT_PID=''
    WSLX_INIT_CMD_FILE='' WSLX_INIT_CMD=''

    # Get zero pid
    [ -n "$WSLX_ZERO_PID_FILE" ] && [ -f "$WSLX_ZERO_PID_FILE" ] && read -r WSLX_ZERO_PID _READ_ <"$WSLX_ZERO_PID_FILE" 2>/dev/null
    [ -n "$WSLX_ZERO_PID" ] && WSLX_INIT_PID_FILE="/proc/${WSLX_ZERO_PID}/task/${WSLX_ZERO_PID}/children"

    while true; do
        # Get init pid
        [ -n "$WSLX_INIT_PID_FILE" ] && [ -f "$WSLX_INIT_PID_FILE" ] && read -r WSLX_INIT_PID _READ_ <"$WSLX_INIT_PID_FILE" 2>/dev/null
        [ -n "$WSLX_INIT_PID" ] && WSLX_INIT_CMD_FILE="/proc/${WSLX_INIT_PID}/comm"

        # Get init command
        [ -n "$WSLX_INIT_CMD_FILE" ] && [ -f "$WSLX_INIT_CMD_FILE" ] && read -r WSLX_INIT_CMD _READ_ <"$WSLX_INIT_CMD_FILE" 2>/dev/null

        # Process is unshare, then get its children
        [ "${WSLX_INIT_CMD##*/}" = 'unshare' ] && WSLX_INIT_PID_FILE="/proc/${WSLX_INIT_PID}/task/${WSLX_INIT_PID}/children" && continue

        # Process is not unshare, break
        break
    done

    # Found init process, break
    [ -n "$WSLX_INIT_PID" ] && break

    # Not found init process, wait and retry
    sleep .5
    WSLX_TIMES=$((WSLX_TIMES + 1))
done

# Found init process, enter its namespace and exec shell
if [ -n "$WSLX_INIT_PID" ]; then
    : "${PWD:=$(pwd)}"
    exec /usr/bin/nsenter -m -u -i -p -C -w"$PWD" -t "$WSLX_INIT_PID" -- "${SHELL:-/bin/sh}"
fi
