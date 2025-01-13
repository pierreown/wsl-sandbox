#!/bin/bash

set -e

export E_RED="\033[31m"
export E_GRE="\033[32m"
export E_YEL="\033[33m"
export E_BLU="\033[34m"
export E_WHI="\033[37m"
export E_PLA="\033[0m"

fmt() {
    local FMT_TYPE="$1"
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

Usage: $0 [options]

Options:
  -f, --force       Force install dependencies
  --cdn             Use CDN for script downloads
  -h, --help        Show this help

EOF
}

check_missing_commands() {
    local CMD CMD_PATH
    local MISSING=0
    for CMD in "$@"; do
        CMD_PATH=$(command -v "${CMD}" 2>/dev/null || true)
        if [ -n "${CMD_PATH}" ]; then
            CMD_PATH=$(readlink -f "${CMD_PATH}" 2>/dev/null || true)
        fi
        case "$CMD_PATH" in
        "")
            fmt TIP "Command missing: $CMD"
            ;;
        */busybox)
            fmt TIP "Command provided by busybox: $CMD"
            ;;
        *) continue ;;
        esac
        MISSING=1
    done
    return $MISSING
}

install_dependencies() {
    fmt TIT "Install Dependencies"

    set -- "wget" "unshare" "nsenter" "mount" "umount"

    if [ "$FORCE" -eq 1 ]; then
        fmt INF "Force install dependencies..."
    elif ! check_missing_commands "$@"; then
        fmt INF "Missing some dependencies, trying to install..."
    else
        fmt INF "Founded all dependencies, skip"
        return 0
    fi

    set -- wget util-linux

    if type apt-get >/dev/null 2>&1; then
        apt-get update || true
        apt-get install -q -y "$@"
    elif type dnf >/dev/null 2>&1; then
        dnf install -y "$@"
    elif type yum >/dev/null 2>&1; then
        yum install -y "$@"
    elif type apk >/dev/null 2>&1; then
        apk add -q "$@"
    elif type zypper >/dev/null 2>&1; then
        zypper -q install -y "$@"
    elif type pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm "$@"
    else
        fmt ERR "Not Found Supported Package Manager" >&2
        fmt TIP "Please install by yourself:" "$@"
        exit 1
    fi

    local EXIT_CODE=$?
    if [ "$EXIT_CODE" -eq 0 ]; then
        fmt SUC "Installed:" "$@"
    else
        fmt ERR "Failed to install dependencies" >&2
        fmt TIP "Please install by yourself:" "$@"
        exit 1
    fi
}

download_scripts() {
    fmt TIT "Download & Install"

    local BASE_URL="https://raw.githubusercontent.com/pierreown/wsl-sandbox/main"
    local INSTALL_PREFIX="/usr/local/wsl-sandbox"
    local LINKED_PATH="/usr/local/bin"
    local SCRIPT

    if [ "$CDN" -eq 1 ]; then
        fmt INF "Use CDN"
        BASE_URL="https://cdn.jsdelivr.net/gh/pierreown/wsl-sandbox@main"
    fi

    # Cleanup old files
    { rm -rf "${INSTALL_PREFIX}" && mkdir -p "${INSTALL_PREFIX}"; } || true

    # Download Scripts
    set -- wsl-sandbox.sh wsl-init.sh wsl-boot.sh wsl-enter.sh
    for SCRIPT in "$@"; do
        if wget -q -t 3 -w 1 -T 5 -O "${INSTALL_PREFIX}/${SCRIPT}" "${BASE_URL}/${SCRIPT}"; then
            chmod +x "${INSTALL_PREFIX}/${SCRIPT}"
            fmt SUC "Downloaded ${INSTALL_PREFIX}/${SCRIPT}"
        else
            fmt ERR "Failed to download ${INSTALL_PREFIX}/${SCRIPT}" >&2 && exit 1
        fi
    done

    # Create Symlink
    set -- wsl-sandbox.sh wsl-init.sh
    for SCRIPT in "$@"; do
        ln -sf "${INSTALL_PREFIX}/${SCRIPT}" "${LINKED_PATH}/${SCRIPT%.sh}"
        fmt SUC "Linked ${INSTALL_PREFIX}/${SCRIPT} => ${LINKED_PATH}/${SCRIPT%.sh}"
    done
}

# Check User
[ "$(id -u)" -ne 0 ] && fmt ERR "Please run as root" >&2 && exit 1

# Parse Options
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

# Main Flow
install_dependencies
download_scripts
