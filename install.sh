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
