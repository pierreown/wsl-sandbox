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

usage() {
    cat <<EOF

Usage: install [options]

Flags:
  -f, --force       Force install dependencies
  -h, --help        Show this help

EOF
}

# Check User
[ "$(id -u)" -ne 0 ] && FMT ERR "Please run as root" >&2 && exit 1

# Options
eval set -- "$(getopt -o ':fh' --long 'force,cdn,help' -- "$@" 2>/dev/null)"
FORCE=0 CDN=0
while true; do
    case "$1" in
    --) shift && break ;;
    -f | --force) FORCE="1" ;;
    --cdn) CDN="1" ;;
    -h | --help) usage && exit ;;
    esac
    shift
done

{
    FMT TIT "Install Dependencies"

    # Check Dependencies
    MISSED_CMD=0
    if [ "$FORCE" -ne 1 ]; then
        for CMD in wget unshare nsenter mount umount; do
            CMD_PATH=$(command -v "$CMD" 2>/dev/null || true)
            [ -z "$CMD_PATH" ] || CMD_PATH=$(readlink -f "$CMD_PATH" 2>/dev/null || true)
            case "$CMD_PATH" in
            */busybox) MISSED_CMD=1 && FMT TIP "Found Command, but its busybox: $CMD" ;;
            "") MISSED_CMD=1 && FMT TIP "Missing Command: $CMD" ;;
            esac
        done
    fi

    if [ "$FORCE" -ne 1 ] && [ "$MISSED_CMD" -ne 1 ]; then
        # All Dependencies Found
        FMT INF "Not Found Missing Dependencies, Skip"
    else
        # Install Dependencies

        [ "$FORCE" -eq 1 ] || FMT INF "Missing required commands, trying to install dependencies..."

        PKGS="" EXIT_CODE=0
        if type apt-get >/dev/null 2>&1; then
            apt-get update
            apt-get install -q -y wget util-linux
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
    echo
}

{
    FMT TIT "Download & Install"

    # clean up old files
    rm -rf /usr/local/wsl-sandbox
    mkdir -p /usr/local/wsl-sandbox

    BASE_URL="https://raw.githubusercontent.com/pierreown/wsl-sandbox/main"
    if [ "$CDN" -eq 1 ]; then
        FMT INF "Use CDN"
        BASE_URL="https://cdn.jsdelivr.net/gh/pierreown/wsl-sandbox@main"
    fi

    # download
    for SCRIPT in wsl-sandbox.sh wsl-init.sh wsl-boot.sh wsl-enter.sh; do
        if wget -q -t 3 -w 1 -T 5 -O "/usr/local/wsl-sandbox/${SCRIPT}" "${BASE_URL}/${SCRIPT}"; then
            chmod +x "/usr/local/wsl-sandbox/${SCRIPT}"
            FMT SUC "Downloaded /usr/local/wsl-sandbox/${SCRIPT}"
        else
            FMT ERR "Failed to download /usr/local/wsl-sandbox/${SCRIPT}" >&2 && exit 1
        fi
    done

    # link to PATH
    for SCRIPT in wsl-sandbox.sh wsl-init.sh; do
        ln -sf "/usr/local/wsl-sandbox/${SCRIPT}" "/usr/local/bin/${SCRIPT%.sh}"
        FMT SUC "Linked /usr/local/wsl-sandbox/${SCRIPT} => /usr/local/bin/${SCRIPT%.sh}"
    done
    echo
}
