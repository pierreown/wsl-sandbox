#!/bin/sh

INIT_PID_FILE="/var/run/sbox-wsl-init.pid"
INIT_PID=""

# Retry up to 20 times to get init PID
RETRY_TIMES=0
while [ $RETRY_TIMES -lt 20 ]; do
    [ -f "$INIT_PID_FILE" ] && read -r INIT_PID <"$INIT_PID_FILE" 2>/dev/null
    [ -n "$INIT_PID" ] && break
    sleep 0.5
    RETRY_TIMES=$((RETRY_TIMES + 1))
done
[ -n "$INIT_PID" ] || return

# Exit if process doesn't exist
[ -e "/proc/$INIT_PID/exe" ] || return

# Default to shell if no command provided
[ $# -gt 0 ] || set -- "${SHELL:-/bin/sh}"

# Default to current working directory
WORK_DIR="$(pwd)" && : "${WORK_DIR:=/}"

# Enter the namespace of the init process
exec nsenter --all --preserve-credentials --target "$INIT_PID" -- sh -c "
    [ -d '${WORK_DIR}' ] && cd '${WORK_DIR}' || true
    unset OLDPWD
    exec \"\$@\"
" -- "$@"
