#!/bin/sh

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

ini() { cp -f -- "$1" "${1}.old" && awk -F'=' -v SECTION="$2" -v KEY="$3" -v NEW_VALUE="$4" "$AWK_SET_MODULE" "${1}.old" >"$1"; }

fmt() {
    _FMT_TYPE="$1"
    case "$_FMT_TYPE" in
    TIT) shift && printf "${E_BLU}--- %s ---${E_PLA}\n" "$*" && return ;;
    SUC) shift && printf "${E_GRE}%s${E_PLA} " "$_FMT_TYPE" ;;
    ERR) shift && printf "${E_RED}%s${E_PLA} " "$_FMT_TYPE" ;;
    WRN | TIP) shift && printf "${E_YEL}%s${E_PLA} " "$_FMT_TYPE" ;;
    INF) shift && printf "${E_YEL}%s${E_PLA} " "$_FMT_TYPE" ;;
    esac
    printf "%s\n" "$*"
}

usage() {
    cat <<EOF

Usage: $0 [command]

Flags:
  -h, --help        Show this help

Commands:
  enable            Enable WSL Init
  disable           Disable WSL Init

EOF
}

enable_wsl_init() {
    fmt TIT "Enable WSL Init"

    [ -f /etc/wsl.conf ] || touch /etc/wsl.conf
    ini '/etc/wsl.conf' 'boot' 'command' '/usr/local/sandbox/wsl-boot.sh'
    fmt SUC "Modified /etc/wsl.conf, saved old file to *.old"

    cat <<EOF >/etc/profile.d/99-wsl-init-enter.sh
#!/bin/sh
if [ -x /usr/local/sandbox/wsl-enter.sh ]; then
    exec /usr/local/sandbox/wsl-enter.sh
fi
EOF
    fmt SUC "Created /etc/profile.d/99-wsl-init-enter.sh"
}

disable_wsl_init() {
    fmt TIT "Disable WSL Init"

    [ -f /etc/wsl.conf ] || touch /etc/wsl.conf
    ini '/etc/wsl.conf' 'boot' 'command' ''
    fmt SUC "Modified /etc/wsl.conf, saved old file to *.old"

    rm -f /etc/profile.d/99-wsl-init-enter.sh
    fmt SUC "Removed /etc/profile.d/99-wsl-init-enter.sh"
}

# Check User
[ "$(id -u)" -ne 0 ] && fmt ERR "Please run as root" >&2 && exit 1

# Parse Options
eval set -- "$(getopt -o ':h' --long 'help' -- "$@" 2>/dev/null)"
while true; do
    case "$1" in
    --) shift && break ;;
    -h | --help) usage && exit ;;
    esac
    shift
done

# Main Flow
case "$1" in
enable)
    enable_wsl_init
    ;;
disable)
    disable_wsl_init
    ;;
'')
    usage
    ;;
*)
    fmt ERR "Invalid Command: $*" 2>&1
    usage && exit 1
    ;;
esac
