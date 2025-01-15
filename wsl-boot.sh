#!/bin/sh

set -e

INIT_PID_FILE="/var/run/sbox-wsl-init.pid"

# Clear the init PID file
: >"$INIT_PID_FILE" #

# Create a named pipe (FIFO)
PIPE="/var/run/sandbox-wsl-init.pipe"
[ ! -p "$PIPE" ] || rm -f "$PIPE"
mkfifo "$PIPE" 2>/dev/null

# Start unshare with a new PID and mount namespace, and run /sbin/init
unshare --fork --pid --mount-proc -- sh -c "echo 'ok' >'$PIPE'; exec /sbin/init;" &
BOOT_PID=$!

# Wait for the child process to notify the parent
read -r _ <"$PIPE"
rm -f "$PIPE"

# Check if the children file exists
CHILDS_FILE="/proc/$BOOT_PID/task/$BOOT_PID/children"
[ -f "$CHILDS_FILE" ] || exit 1

# Read the children PIDs
set -- "$(cat "$CHILDS_FILE")"

# Find the init process
INIT_PID="$1"
for CHILD_PID in "$@"; do
    [ -f "/proc/$CHILD_PID/comm" ] || continue
    read -r COMM <"/proc/$CHILD_PID}comm"
    [ "${COMM##*/}" = 'init' ] || continue
    INIT_PID="$CHILD_PID"
    break
done
[ -n "$INIT_PID" ] || exit 1

# Write the init PID to the file
echo "$INIT_PID" >"$INIT_PID_FILE"

# Print the init PID
echo "$INIT_PID"

kill -9 "$BOOT_PID"
