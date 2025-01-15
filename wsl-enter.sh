#!/bin/sh

INIT_PID_FILE="/var/run/sbox-wsl-init.pid"
# shellcheck disable=SC2016
FORK_SCRIPT='
[ -d "$WORK_DIR" ] && cd "$WORK_DIR" || true
unset OLDPWD WORK_DIR
exec "$@"
'

if [ -z "$SBOX_WSL_ENTER" ]; then
    INIT_PID=""
    WORK_DIR="$(pwd)" && : "${WORK_DIR:=/}"

    # Default to shell if no command provided
    [ $# -gt 0 ] || set -- "${SHELL:-/bin/sh}"

    # Retry up to 20 times to get init PID
    RETRY_TIMES=0
    while [ $RETRY_TIMES -lt 20 ]; do
        [ -f "$INIT_PID_FILE" ] && read -r INIT_PID <"$INIT_PID_FILE" 2>/dev/null
        [ -n "$INIT_PID" ] && break
        sleep 0.5
        RETRY_TIMES=$((RETRY_TIMES + 1))
    done

    if [ -n "$INIT_PID" ] && [ -e "/proc/$INIT_PID/exe" ]; then
        # Export variables
        export SBOX_WSL_ENTER=1
        export WORK_DIR

        # Enter the namespace of the init process
        exec nsenter --all --target "$INIT_PID" -- sh -c "$FORK_SCRIPT" -- "$@"
    else
        exec "$@"
    fi
fi

unset INIT_PID_FILE FORK_SCRIPT
