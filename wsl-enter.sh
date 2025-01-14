#!/bin/sh

# custom pid file
SBOX_ZERO_PID_FILE="/var/run/wsl-init-sandbox.pid"

wait_for_init() {
    _TIMES=0

    # maximum 20 times of attempts
    while [ $_TIMES -lt 20 ]; do
        _ZERO_PID="" _ZERO_PID_FILE="${SBOX_ZERO_PID_FILE}"
        _INIT_PID="" _INIT_PID_FILE=""
        _INIT_CMD="" _INIT_CMD_FILE=""

        # find zero pid
        [ -n "$_ZERO_PID_FILE" ] && [ -f "$_ZERO_PID_FILE" ] && read -r _ZERO_PID _READ_ <"$_ZERO_PID_FILE" 2>/dev/null
        [ -n "$_ZERO_PID" ] && _INIT_PID_FILE="/proc/${_ZERO_PID}/task/${_ZERO_PID}/children"

        while true; do
            # find init process pid
            [ -n "$_INIT_PID_FILE" ] && [ -f "$_INIT_PID_FILE" ] && read -r _INIT_PID _READ_ <"$_INIT_PID_FILE" 2>/dev/null
            [ -n "$_INIT_PID" ] && _INIT_CMD_FILE="/proc/${_INIT_PID}/comm"

            # find init process command
            [ -n "$_INIT_CMD_FILE" ] && [ -f "$_INIT_CMD_FILE" ] && read -r _INIT_CMD _READ_ <"$_INIT_CMD_FILE" 2>/dev/null

            # process is unshare, then get its children
            [ "${_INIT_CMD##*/}" = 'unshare' ] && _INIT_PID_FILE="/proc/${_INIT_PID}/task/${_INIT_PID}/children" && continue

            # process is not unshare, break
            break
        done

        # found init process, break
        if [ -n "$_INIT_PID" ]; then
            SBOX_INIT_PID="${_INIT_PID}"
            break
        fi

        # not found init process, wait and retry
        sleep .5
        _TIMES=$((_TIMES + 1))
    done
}

enter_sandbox() {
    # wait for init process
    wait_for_init

    _INIT_PID="${SBOX_INIT_PID}"

    # cannot get init process, exit
    [ -n "$_INIT_PID" ] || return

    _WORK_DIR="$(pwd)"

    # export variables for child process
    export SBOX_ENV_WORK_DIR="${_WORK_DIR}"

    # default exec shell
    [ $# -gt 0 ] || set -- "${SHELL:-/bin/sh}"

    # enter its namespace and exec shell
    # not use '-W' flag, because work directory may be not exist in namespace
    # shellcheck disable=SC2016
    exec nsenter -a -F -t "${_INIT_PID}" -- sh -c '
        _WORK_DIR="${SBOX_ENV_WORK_DIR}"

        # change work directory
        if [ -d "${_WORK_DIR:="/"}" ]; then
            cd "${_WORK_DIR}" 2>/dev/null || true
        fi

        # cleanup environment
        unset OLDPWD
        unset SBOX_ENV_WORK_DIR

        # execute
        exec "$@"
    ' -- "$@"
}

enter_sandbox "$@"
