#!/bin/bash

set -e

WSLX_SANDBOX_PREFIX="/sandbox"

if [ "$1" == "setup" ]; then
    shift
else
    WSLX_PID_FILE="$WSLX_ZERO_PID_FILE" && unset WSLX_ZERO_PID_FILE

    # 创建独立命名空间
    if [ -n "$WSLX_NAME" ]; then
        WSLX_SESSION="${WSLX_SANDBOX_PREFIX}/${WSLX_NAME}" && unset WSLX_NAME
        mkdir -p "${WSLX_SESSION}"

        echo "$$" >"${WSLX_PID_FILE:-${WSLX_SESSION}/zero.pid}"
        export WSLX_SESSION
        exec unshare -m -u -i -p -C --mount-proc --propagation slave -f -- "$0" setup "$@"
    else
        WSLX_SESSION="$(mktemp -u -p "${WSLX_SANDBOX_PREFIX}" -t overlay.XXXXXXXX)"
        mkdir -p "${WSLX_SESSION}"
        trap 'rm -rf "$WSLX_SESSION"' EXIT

        echo "$$" >"${WSLX_PID_FILE:-${WSLX_SESSION}/zero.pid}"
        export WSLX_SESSION
        unshare -m -u -i -p -C --mount-proc --propagation slave -f -- "$0" setup "$@"
    fi
    exit
fi

WSLX_DIR="$WSLX_SESSION"
unset WSLX_SESSION

if [ -z "$WSLX_DIR" ] || [ ! -d "$WSLX_DIR" ]; then
    echo "invalid operation" >&2 && exit 1
fi

# 挂载 overlay 文件系统
WSLX_ROOT="${WSLX_DIR}/root"
mkdir -p "${WSLX_DIR}/upper" "${WSLX_DIR}/work" "$WSLX_ROOT"
mount -t overlay overlay -o "lowerdir=/,upperdir=${WSLX_DIR}/upper,workdir=${WSLX_DIR}/work" "$WSLX_ROOT"

# 隐藏不必要的文件
for WSLX_HIDE_ITEM in "$WSLX_SANDBOX_PREFIX" /init; do
    [ -e "$WSLX_HIDE_ITEM" ] || continue
    WSLX_HIDE_ITEM="${WSLX_DIR}/upper${WSLX_HIDE_ITEM}"
    if [ ! -e "$WSLX_HIDE_ITEM" ]; then
        mkdir -p "$WSLX_HIDE_ITEM" && rm -rf "$WSLX_HIDE_ITEM" &&
            mknod "$WSLX_HIDE_ITEM" c 0 0 # 创建字符设备文件 (0, 0)
    fi
done

# 挂载嵌套目录
mkdir -p "${WSLX_DIR}/nested" "${WSLX_ROOT}${WSLX_SANDBOX_PREFIX}"
mount -o bind "${WSLX_DIR}/nested" "${WSLX_ROOT}/${WSLX_SANDBOX_PREFIX}"

# 挂载必要系统目录
mount -t proc proc "${WSLX_ROOT}/proc" -o rw,nosuid,nodev,noexec,noatime
mount -t sysfs sysfs "${WSLX_ROOT}/sys" -o rw,nosuid,nodev,noexec,noatime

# mount -o rbind "/sys/fs/cgroup" "${WSLX_ROOT}/sys/fs/cgroup"
mount -t cgroup2 cgroup "${WSLX_ROOT}/sys/fs/cgroup"

# mount -o rbind "/proc/sys/fs/binfmt_misc" "${WSLX_ROOT}/proc/sys/fs/binfmt_misc"
mount -t binfmt_misc binfmt_misc "${WSLX_ROOT}/proc/sys/fs/binfmt_misc"

mount -o rbind "/dev" "${WSLX_ROOT}/dev"
mount -o rbind "/run" "${WSLX_ROOT}/run"
mount -o rbind "/mnt" "${WSLX_ROOT}/mnt"

# 挂载 WSL 目录
for WSLX_RBIND in /usr/lib/wsl /tmp/.X11-unix; do
    WSLX_RBIND_DST="${WSLX_ROOT}${WSLX_RBIND}"
    if [ -d "${WSLX_RBIND}" ] && [ -d "${WSLX_RBIND_DST}" ]; then
        mount -o rbind "${WSLX_RBIND}" "${WSLX_RBIND_DST}"
    fi
done

# 切换根文件系统，并执行命令
cd "$WSLX_ROOT" || exit 1

WSLX_ROM="$(mktemp -u -p / -t .ROM.XXXXXX)"
mkdir -p "${WSLX_ROOT}${WSLX_ROM}"
pivot_root "${WSLX_ROOT}" "${WSLX_ROOT}${WSLX_ROM}"
umount -l "${WSLX_ROM}"
rm -rf "${WSLX_ROM}"

[ $# -gt 0 ] || set -- "${SHELL:-/bin/sh}"
exec "$@"
