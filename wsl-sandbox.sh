#!/bin/sh

set -e

# 创建独立命名空间
if [ "$1" != "setup" ]; then
    [ -n "$WSLX_ZERO_PID_FILE" ] && echo "$$" >"$WSLX_ZERO_PID_FILE"
    unset WSLX_ZERO_PID_FILE
    exec unshare -m -i -p --mount-proc -f -- "$0" setup "$@"
fi

shift

# 挂载 overlay 文件系统
mkdir -p /overlay/upper /overlay/work /overlay/root
mount -t overlay overlay -o lowerdir=/,upperdir=/overlay/upper,workdir=/overlay/work /overlay/root

# 隐藏不必要的文件
for WSLX_HIDE_ITEM in /overlay /init; do
    WSLX_HIDE_ITEM="/overlay/upper${WSLX_HIDE_ITEM}"
    [ ! -e "$WSLX_HIDE_ITEM" ] && mknod "$WSLX_HIDE_ITEM" c 0 0 # 创建字符设备文件 (0, 0)
done

WSLX_ROOT="/overlay/root"

# 挂载必要系统目录
mount -t proc proc "${WSLX_ROOT}/proc" -o rw,nosuid,nodev,noexec,noatime
mount -t sysfs sysfs "${WSLX_ROOT}/sys" -o rw,nosuid,nodev,noexec,noatime
mount -t binfmt_misc binfmt_misc "${WSLX_ROOT}/proc/sys/fs/binfmt_misc"
mount -t cgroup2 cgroup2 "${WSLX_ROOT}/sys/fs/cgroup"
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

WSLX_MODE="pivot"

# 切换根文件系统，并执行命令
case "$WSLX_MODE" in
chroot)
    cd "$WSLX_ROOT" || exit 1

    [ $# -gt 0 ] || set -- "${SHELL:-/bin/sh}"
    exec chroot "$WSLX_ROOT" "$@"
    ;;
pivot)
    cd "$WSLX_ROOT" || exit 1

    WSLX_ROM="$(mktemp -u -p / -t .ROM.XXXXXX)"
    mkdir -p "${WSLX_ROOT}${WSLX_ROM}"
    pivot_root "${WSLX_ROOT}" "${WSLX_ROOT}${WSLX_ROM}"
    umount -l "${WSLX_ROM}"
    rm -rf "${WSLX_ROM}"

    [ $# -gt 0 ] || set -- "${SHELL:-/bin/sh}"
    exec "$@"
    ;;
esac
