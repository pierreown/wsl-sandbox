#!/bin/sh

set -e

SBOX_PREFIX="/sandbox"
SBOX_PID_NAME="box.pid"

randomx() { head -c "$1" /dev/urandom | md5sum | head -c "$1"; }

setup() {
    PREFIX="${SBOX_PREFIX:?}"
    PID_NAME="${SBOX_PID_NAME:?}"

    # random sandbox name
    NAME="" DIR_NAME=""
    while true; do
        NAME="$(randomx 16)"
        DIR_NAME="sbox.$NAME"
        [ ! -e "$PREFIX/$DIR_NAME" ] && break
    done

    # sandbox directory
    BASE_DIR="$PREFIX/$DIR_NAME"
    WORK_DIR="$(pwd)"
    PID_FILE="$BASE_DIR/$PID_NAME"

    # init flag
    [ -e "$BASE_DIR" ] || INIT_FLAG=1

    # create sandbox directory
    mkdir -p "$BASE_DIR"

    # create pid file
    echo "$$" >"$PID_FILE"

    # export variables for child process
    export SBOX_FORK=1
    export SBOX_NAME="$NAME"
    export SBOX_BASE_DIR="$BASE_DIR"
    export SBOX_WORK_DIR="$WORK_DIR"
    export SBOX_INIT_FLAG="$INIT_FLAG"

    # default exec shell
    [ $# -gt 0 ] || set -- "${SHELL:-/bin/sh}"

    # temp sandbox need cleanup by trap, cannot use 'exec'
    trap '[ -n "$SBOX_BASE_DIR" ] && rm -rf "$SBOX_BASE_DIR"' EXIT
    unshare -m -u -i -C -p -f --mount-proc --propagation slave -- "$0" "$@"
}

setup_fork() {
    PREFIX="${SBOX_PREFIX:?}"
    NAME="${SBOX_NAME:?}"
    BASE_DIR="${SBOX_BASE_DIR:?}"
    WORK_DIR="${SBOX_WORK_DIR:-/}"
    INIT_FLAG="${SBOX_INIT_FLAG:-}"

    # check sandbox directory
    if [ ! -d "$BASE_DIR" ]; then
        echo "Invalid sandbox directory" >&2 && exit 1
    fi

    OVER_UPPER="$BASE_DIR/upper" OVER_WORK="$BASE_DIR/work" ROOT_DIR="$BASE_DIR/root"
    mkdir -p "$OVER_UPPER" "$OVER_WORK" "$ROOT_DIR"

    # hide some path
    for ITEM in "$PREFIX" "/init"; do
        if [ -e "$ITEM" ] && [ ! -e "$OVER_UPPER$ITEM" ]; then
            mkdir -p "$(dirname "$OVER_UPPER$ITEM")"
            mknod "$OVER_UPPER$ITEM" c 0 0 # create a placeholder character device
        fi
    done

    # mount tmpfs config directory
    OVER_CONF="$BASE_DIR/conf"
    mkdir -p "$OVER_CONF"
    mount -t tmpfs tmpfs "$OVER_CONF"

    # create config files
    mkdir -p "$OVER_CONF/etc"
    echo "$NAME" >"$OVER_CONF/etc/hostname"

    # mount overlay directory
    mount -t overlay overlay -o "lowerdir=$OVER_CONF:/,upperdir=$OVER_UPPER,workdir=$OVER_WORK" "$ROOT_DIR"

    # mount nested directory
    mkdir -p "$BASE_DIR/nested" "$ROOT_DIR$PREFIX"
    mount -o bind "$BASE_DIR/nested" "$ROOT_DIR$PREFIX"

    # mount system directories
    mount -t proc proc "$ROOT_DIR/proc" -o rw,nosuid,nodev,noexec,noatime
    mount -t sysfs sysfs "$ROOT_DIR/sys" -o rw,nosuid,nodev,noexec,noatime
    mount -t cgroup2 cgroup "$ROOT_DIR/sys/fs/cgroup"
    mount -t binfmt_misc binfmt_misc "$ROOT_DIR/proc/sys/fs/binfmt_misc"
    mount -o rbind "/dev" "$ROOT_DIR/dev"
    mount -o rbind "/run" "$ROOT_DIR/run"

    # mount wsl support directories
    for ITEM in "/mnt" "/tmp/.X11-unix" "/usr/lib/wsl"; do
        [ -d "$ITEM" ] || continue
        mount -o rbind "$ITEM" "$ROOT_DIR$ITEM"
    done

    cd "$ROOT_DIR" || exit 1

    # change root directory
    ROOT_ORG="/.root.org"
    mkdir -p "$ROOT_DIR$ROOT_ORG"
    pivot_root "$ROOT_DIR" "$ROOT_DIR$ROOT_ORG"
    umount -l "$ROOT_ORG" && rm -rf "$ROOT_ORG" # hide original root

    # change work directory
    { [ -d "$WORK_DIR" ] && cd "$WORK_DIR" 2>/dev/null; } || true

    # settings
    if [ "$INIT_FLAG" = "1" ]; then
        hostname "$NAME"
    fi

    # cleanup environment
    unset OLDPWD
    unset SBOX_FORK SBOX_NAME SBOX_BASE_DIR SBOX_WORK_DIR SBOX_INIT_FLAG

    # execute
    exec "$@"
}

if [ "$SBOX_FORK" = "1" ]; then
    setup_fork "$@"
    exit
fi

setup "$@"
