#!/bin/sh

[ "$(id -u)" -ne 0 ] && echo "Please run as root" && exit 1

export E_RED="\033[31m"
export E_GRE="\033[32m"
export E_YEL="\033[33m"
export E_BLU="\033[34m"
export E_WHI="\033[37m"
export E_PLA="\033[0m"

# shellcheck disable=SC2016
AWK_SET_MODULE='
BEGIN {
    flag = 0;
}

flag == 2 {
    print $0;
    next;
}

$0 ~ "^ *\\[" SECTION "\\] *$" {
    flag = 1;
    print $0;
    next;
}

/^ *\[/ {
    flag = 0;
    print $0;
    next;
}

flag && $0 ~ "^ *" KEY " *=" {
    # print "# " $0;
    print KEY " = " "\"" NEW_VALUE "\"";
    flag = 2;
    next;
}

{
    print $0;
}

END {
    if (flag == 2) {
        exit;
    }

    if (flag == 0) {
        print "[" SECTION "]";
    }

    print KEY " = " "\"" NEW_VALUE "\"";
}'

INI_SET() { awk -F'=' -v SECTION="$2" -v KEY="$3" -v NEW_VALUE="$4" "$AWK_SET_MODULE" "$1" >"${1}.old" && cp -f "${1}.old" "$1"; }
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

{
    FMT TIT "Download & Install"

    rm -rf /usr/local/wsl-init
    mkdir -p /usr/local/wsl-init

    BASE_URL="https://raw.githubusercontent.com/pierreown/wsl-init/refs/heads/main"
    for SCRIPT in wsl-init wsl-enter; do
        wget -q "${BASE_URL}/${SCRIPT}" -O "/usr/local/wsl-init/${SCRIPT}"
        chmod +x "/usr/local/wsl-init/${SCRIPT}"
        FMT SUC "Downloaded /usr/local/wsl-init/${SCRIPT}"
    done

    ln -sf /usr/local/wsl-init/wsl-enter /usr/local/bin/wsl-enter
    FMT SUC "Linked /usr/local/wsl-init/wsl-enter => /usr/local/bin/wsl-enter"
}

{
    FMT TIT "Configuration"

    [ -f /etc/wsl.conf ] || touch /etc/wsl.conf
    INI_SET '/etc/wsl.conf' 'boot' 'command' '/usr/local/wsl-init/wsl-init /sbin/init'
    FMT SUC "Modified /etc/wsl.conf"

    echo "[ -x /usr/local/bin/wsl-enter ] && exec /usr/local/bin/wsl-enter" >/etc/profile.d/99-wsl-enter.sh
    FMT SUC "Created /etc/profile.d/99-wsl-enter.sh"
}
