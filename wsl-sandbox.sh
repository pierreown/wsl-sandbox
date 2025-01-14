#!/bin/sh

set -e

SBOX_PREFIX="/var/lib/wsl-sandbox"
SBOX_PID_NAME="box.pid"

setup_sandbox() {
    _PREFIX="${SBOX_PREFIX:?}"
    _PID_NAME="${SBOX_PID_NAME:?}"
    _NAME="${SBOX_ENV_NAME}"
    _PID_FILE_CUSTOM="${SBOX_ENV_PID_FILE}"
    _DIR_NAME="" _IS_TEMP=0

    if [ -n "${_NAME}" ]; then
        # named sandbox is permanent
        _IS_TEMP=0
        _DIR_NAME="${_NAME}"
    else
        # non-named sandbox is temp
        _IS_TEMP=1
        while true; do
            _NAME="$(mktemp -u SB-XXXXXX)"
            _DIR_NAME="TEMP-${_NAME}"
            [ ! -e "${_PREFIX}/${_DIR_NAME}" ] && break
        done
    fi

    _BASE_DIR="${_PREFIX}/${_DIR_NAME}"
    _PID_FILE="${_BASE_DIR}/${_PID_NAME}"

    # create sandbox directory
    mkdir -p "${_BASE_DIR}"

    # create default pid file
    echo "$$" >"${_PID_FILE}"

    # create custom pid file
    if [ -n "${_PID_FILE_CUSTOM}" ]; then
        mkdir -p "$(dirname "${_PID_FILE_CUSTOM}")"
        echo "$$" >"${_PID_FILE_CUSTOM}"
    fi

    # cleanup environment
    unset SBOX_ENV_PID_FILE

    # export variables for child process
    export SBOX_ENV_FORK=1
    export SBOX_ENV_NAME="${_NAME}"
    export SBOX_ENV_BASE_DIR="${_BASE_DIR}"
    export SBOX_ENV_WORK_DIR="${SBOX_ENV_WORK_DIR:-$(pwd)}"

    # default exec shell
    [ $# -gt 0 ] || set -- "${SHELL:-/bin/sh}"

    # temp sandbox need cleanup by trap, cannot use 'exec'
    if [ "${_IS_TEMP}" -eq 1 ]; then
        trap '[ -n "${SBOX_ENV_BASE_DIR}" ] && rm -rf "${SBOX_ENV_BASE_DIR}"' EXIT
        unshare -m -u -i -p -C --mount-proc --propagation slave -f -- "$0" "$@"
    else
        exec unshare -m -u -i -p -C --mount-proc --propagation slave -f -- "$0" "$@"
    fi
}

setup_sandbox_fork() {
    _PREFIX="${SBOX_PREFIX:?}"
    _NAME="${SBOX_ENV_NAME:?}"
    _BASE_DIR="${SBOX_ENV_BASE_DIR:?}"
    _WORK_DIR="${SBOX_ENV_WORK_DIR}"

    # check sandbox directory
    if [ ! -d "$_BASE_DIR" ]; then
        echo "Invalid sandbox directory" >&2 && exit 1
    fi

    _OVER_UPPER="${_BASE_DIR}/upper" _OVER_WORK="${_BASE_DIR}/work" _ROOT_DIR="${_BASE_DIR}/root"
    mkdir -p "${_OVER_UPPER}" "${_OVER_WORK}" "${_ROOT_DIR}"

    # hide some path
    if type mknod >/dev/null 2>&1; then
        for _ITEM in "${_PREFIX}" "/init"; do
            if [ -e "${_ITEM}" ] && [ ! -e "${_OVER_UPPER}${_ITEM}" ]; then
                mkdir -p "$(dirname "${_OVER_UPPER}${_ITEM}")"
                mknod "${_OVER_UPPER}${_ITEM}" c 0 0 # create a placeholder character device
            fi
        done
    fi

    # mount overlay filesystem
    mount -t overlay overlay -o "lowerdir=/,upperdir=${_OVER_UPPER},workdir=${_OVER_WORK}" "${_ROOT_DIR}"

    # mount nested directory
    mkdir -p "${_BASE_DIR}/nested" "${_ROOT_DIR}${_PREFIX}"
    mount -o bind "${_BASE_DIR}/nested" "${_ROOT_DIR}${_PREFIX}"

    # mount system directories
    mount -t proc proc "${_ROOT_DIR}/proc" -o rw,nosuid,nodev,noexec,noatime
    mount -t sysfs sysfs "${_ROOT_DIR}/sys" -o rw,nosuid,nodev,noexec,noatime
    mount -t cgroup2 cgroup "${_ROOT_DIR}/sys/fs/cgroup"
    mount -t binfmt_misc binfmt_misc "${_ROOT_DIR}/proc/sys/fs/binfmt_misc"
    mount -o rbind "/dev" "${_ROOT_DIR}/dev"
    mount -o rbind "/run" "${_ROOT_DIR}/run"

    # mount wsl support directories
    for _ITEM in "/mnt" "/tmp/.X11-unix" "/usr/lib/wsl"; do
        [ -d "${_ITEM}" ] || continue
        mount -o rbind "${_ITEM}" "${_ROOT_DIR}${_ITEM}"
    done

    cd "${_ROOT_DIR}" || exit 1

    # change root directory
    _ROOT_ORG="/.root.org"
    mkdir -p "${_ROOT_DIR}${_ROOT_ORG}"
    pivot_root "${_ROOT_DIR}" "${_ROOT_DIR}${_ROOT_ORG}"
    umount -l "${_ROOT_ORG}" && rm -rf "${_ROOT_ORG}" # hide original root

    # change work directory
    if [ -d "${_WORK_DIR:="/"}" ]; then
        cd "${_WORK_DIR}" 2>/dev/null || true
    fi

    # cleanup environment
    unset OLDPWD
    unset SBOX_ENV_FORK SBOX_ENV_NAME SBOX_ENV_BASE_DIR SBOX_ENV_WORK_DIR

    # execute
    exec "$@"
}

if [ "${SBOX_ENV_FORK}" = "1" ]; then
    setup_sandbox_fork "$@"
    exit
fi

setup_sandbox "$@"
