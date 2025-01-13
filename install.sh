#!/bin/sh

set -e

export E_RED="\033[31m"
export E_GRE="\033[32m"
export E_YEL="\033[33m"
export E_BLU="\033[34m"
export E_WHI="\033[37m"
export E_PLA="\033[0m"

FMT() {
    FMT_TYPE="$1"
    case "$FMT_TYPE" in
    TIT) shift && printf "${E_BLU}--- %s ---${E_PLA}\n" "$*" && return ;;
    SUC) shift && printf "${E_GRE}%s${E_PLA} " "$FMT_TYPE" ;;
    ERR) shift && printf "${E_RED}%s${E_PLA} " "$FMT_TYPE" ;;
    WRN | TIP) shift && printf "${E_YEL}%s${E_PLA} " "$FMT_TYPE" ;;
    INF) shift && printf "${E_WHI}%s${E_PLA} " "$FMT_TYPE" ;;
    esac
    printf "%s\n" "$*"
}

[ "$(id -u)" -ne 0 ] && FMT ERR "Please run as root" >&2 && exit 1

eval set -- "$(getopt -o ':f' --long 'force' -- "$@" 2>/dev/null)"

FORCE=0
while true; do
    case "$1" in
    --) shift && break ;;
    -f | --force) export FORCE="1" && shift ;;
    *) shift ;;
    esac
done

{
    FMT TIT "Install Dependencies"

    MISSED_CMD=0
    if [ "$FORCE" -ne 1 ]; then
        for CMD in wget unshare nsenter mount umount; do
            CMD_PATH=$(command -v "$CMD")
            if [ -z "$CMD_PATH" ]; then
                MISSED_CMD=1
                FMT TIP "Missing Command: $CMD"
            elif [ "$(readlink -f "$CMD_PATH")" = "/bin/busybox" ]; then
                MISSED_CMD=1
                FMT INF "Found Command, but its busybox: $CMD"
            fi
        done
    fi

    if [ "$FORCE" -ne 1 ] && [ "$MISSED_CMD" -ne 1 ]; then
        FMT INF "Not Found Missing Dependencies, Skip"
    else
        [ "$FORCE" -eq 1 ] || FMT INF "Missing required commands, trying to install dependencies..."

        PKGS="" EXIT_CODE=0
        if type apt-get >/dev/null 2>&1; then
            apt-get update
            apt-get install -y wget util-linux
            EXIT_CODE=$?
            PKGS="wget util-linux"
        elif type dnf >/dev/null 2>&1; then
            dnf install -y wget util-linux
            EXIT_CODE=$?
            PKGS="wget util-linux"
        elif type yum >/dev/null 2>&1; then
            yum install -y wget util-linux
            EXIT_CODE=$?
            PKGS="wget util-linux"
        elif type apk >/dev/null 2>&1; then
            apk add -q wget util-linux
            EXIT_CODE=$?
            PKGS="wget util-linux"
        elif type zypper >/dev/null 2>&1; then
            zypper -q install -y wget util-linux
            EXIT_CODE=$?
            PKGS="wget util-linux"
        elif type pacman >/dev/null 2>&1; then
            pacman -Syu --noconfirm wget util-linux
            EXIT_CODE=$?
            PKGS="wget util-linux"
        else
            FMT ERR "Not Found Supported Package Manager. Aborted" >&2 && exit 1
        fi

        [ "$EXIT_CODE" -ne 0 ] && FMT ERR "Failed to install dependencies" >&2 && exit 1
        FMT SUC "Installed $PKGS"
    fi
}

{
    FMT TIT "Download & Install"

    rm -rf /usr/local/wsl-sandbox
    mkdir -p /usr/local/wsl-sandbox

    BASE_URL="https://raw.githubusercontent.com/pierreown/wsl-sandbox/main"
    for SCRIPT in wsl-sandbox.sh wsl-init.sh wsl-boot.sh wsl-enter.sh; do
        if wget -q -t 3 -w 1 -T 5 -O "/usr/local/wsl-sandbox/${SCRIPT}" "${BASE_URL}/${SCRIPT}"; then
            chmod +x "/usr/local/wsl-sandbox/${SCRIPT}"
            FMT SUC "Downloaded /usr/local/wsl-sandbox/${SCRIPT}"
        else
            FMT ERR "Failed to download /usr/local/wsl-sandbox/${SCRIPT}" >&2
        fi
    done

    for SCRIPT in wsl-sandbox.sh wsl-init.sh; do
        ln -sf "/usr/local/wsl-sandbox/${SCRIPT}" "/usr/local/bin/${SCRIPT%.sh}"
        FMT SUC "Linked /usr/local/wsl-sandbox/${SCRIPT} => /usr/local/bin/${SCRIPT%.sh}"
    done
}
