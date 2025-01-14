#!/bin/sh

set -e

export E_RED="\033[31m"
export E_GRE="\033[32m"
export E_YEL="\033[33m"
export E_BLU="\033[34m"
export E_WHI="\033[37m"
export E_PLA="\033[0m"

fmt() {
    _FMT_TYPE="$1"
    case "$_FMT_TYPE" in
    TIT) shift && printf "${E_BLU}--- %s ---${E_PLA}\n" "$*" && return ;;
    SUC) shift && printf "${E_GRE}%s${E_PLA} " "$_FMT_TYPE" ;;
    ERR) shift && printf "${E_RED}%s${E_PLA} " "$_FMT_TYPE" ;;
    WRN | TIP) shift && printf "${E_YEL}%s${E_PLA} " "$_FMT_TYPE" ;;
    INF) shift && printf "${E_WHI}%s${E_PLA} " "$_FMT_TYPE" ;;
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
    _MISSING=0
    for _CMD in "$@"; do
        _CMD_PATH=$(command -v "${_CMD}" 2>/dev/null || true)
        if [ -n "${_CMD_PATH}" ]; then
            _CMD_PATH=$(readlink -f "${_CMD_PATH}" 2>/dev/null || true)
        fi
        case "$_CMD_PATH" in
        "")
            fmt TIP "Command missing: $_CMD"
            ;;
        */busybox)
            fmt TIP "Command provided by busybox: $_CMD"
            ;;
        *) continue ;;
        esac
        _MISSING=1
    done
    return $_MISSING
}

install_dependencies() {
    fmt TIT "Install Dependencies"

    set -- "wget" "unshare" "nsenter" "mount" "umount"

    if [ "$FLAG_FORCE" -eq 1 ]; then
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

    _EXIT_CODE=$?
    if [ "$_EXIT_CODE" -eq 0 ]; then
        fmt SUC "Installed:" "$@"
    else
        fmt ERR "Failed to install dependencies" >&2
        fmt TIP "Please install by yourself:" "$@"
        exit 1
    fi
}

download_scripts() {
    fmt TIT "Download & Install"

    _BASE_URL="https://raw.githubusercontent.com/pierreown/wsl-sandbox/main"
    _PREFIX="/usr/local/wsl-sandbox"
    _LINKED_PATH="/usr/local/bin"

    if [ "$FLAG_CDN" -eq 1 ]; then
        fmt INF "Use CDN"
        _BASE_URL="https://cdn.jsdelivr.net/gh/pierreown/wsl-sandbox@main"
    fi

    # Cleanup old files
    { rm -rf "${_PREFIX}" && mkdir -p "${_PREFIX}"; } || true

    # Download Scripts
    set -- wsl-sandbox.sh wsl-init.sh wsl-boot.sh wsl-enter.sh
    for _ITEM in "$@"; do
        if wget -q -t 3 -w 1 -T 5 -O "${_PREFIX}/${_ITEM}" "${_BASE_URL}/${_ITEM}"; then
            chmod +x "${_PREFIX}/${_ITEM}"
            fmt SUC "Downloaded ${_PREFIX}/${_ITEM}"
        else
            fmt ERR "Failed to download ${_PREFIX}/${_ITEM}" >&2 && exit 1
        fi
    done

    # Create Symlink
    set -- wsl-sandbox.sh wsl-init.sh
    for _ITEM in "$@"; do
        ln -sf "${_PREFIX}/${_ITEM}" "${_LINKED_PATH}/${_ITEM%.sh}"
        fmt SUC "Linked ${_PREFIX}/${_ITEM} => ${_LINKED_PATH}/${_ITEM%.sh}"
    done
}

# Check User
[ "$(id -u)" -ne 0 ] && fmt ERR "Please run as root" >&2 && exit 1

# Parse Options
eval set -- "$(getopt -o ':fh' --long 'force,cdn,help' -- "$@" 2>/dev/null)"
FLAG_FORCE=0 FLAG_CDN=0
while true; do
    case "$1" in
    --) shift && break ;;
    -f | --force) FLAG_FORCE="1" ;;
    --cdn) FLAG_CDN="1" ;;
    -h | --help) usage && exit ;;
    esac
    shift
done

# Main Flow
install_dependencies
download_scripts
