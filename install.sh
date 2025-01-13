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
    INF) shift && printf "${E_YEL}%s${E_PLA} " "$FMT_TYPE" ;;
    esac
    printf "%s\n" "$*"
}

[ "$(id -u)" -ne 0 ] && FMT ERR "Please run as root" >&2 && exit 1

{
    FMT TIT "Install Dependencies"

    if type apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y wget util-linux
    elif type dnf >/dev/null 2>&1; then
        dnf install -y wget util-linux
    elif type yum >/dev/null 2>&1; then
        yum install -y wget util-linux
    elif type apk >/dev/null 2>&1; then
        apk add -q wget util-linux
    elif type zypper >/dev/null 2>&1; then
        zypper -q install -y wget util-linux
    elif type pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm wget util-linux
    else
        MISSED_CMD=0
        for CMD in wget unshare nsenter mount umount; do
            if ! type "$CMD" >/dev/null 2>&1; then
                MISSED_CMD=1
                FMT WRN "Command not found: $CMD" >&2
            fi
        done
        [ "$MISSED_CMD" -eq 1 ] && FMT ERR "Missing required dependencies" >&2 && exit 1
    fi
}

{
    FMT TIT "Download & Install"

    rm -rf /usr/local/wsl-sandbox
    mkdir -p /usr/local/wsl-sandbox

    BASE_URL="https://raw.githubusercontent.com/pierreown/wsl-sandbox/main"
    for SCRIPT in wsl-sandbox.sh wsl-init.sh wsl-boot.sh wsl-enter.sh; do
        wget -q "${BASE_URL}/${SCRIPT}" -O "/usr/local/wsl-sandbox/${SCRIPT}"
        chmod +x "/usr/local/wsl-sandbox/${SCRIPT}"
        FMT SUC "Downloaded /usr/local/wsl-sandbox/${SCRIPT}"
    done

    for SCRIPT in wsl-sandbox.sh wsl-init.sh; do
        ln -sf "/usr/local/wsl-sandbox/${SCRIPT}" "/usr/local/bin/${SCRIPT%.sh}"
        FMT SUC "Linked /usr/local/wsl-sandbox/${SCRIPT} => /usr/local/bin/${SCRIPT%.sh}"
    done
}
