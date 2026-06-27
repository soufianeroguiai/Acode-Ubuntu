export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/share/bin:/usr/share/sbin:/usr/local/bin:/usr/local/sbin:/system/bin:/system/xbin:$PREFIX/local/bin
exec 2> >(grep -v "groups: cannot find" >&2)
export PS1="\[\e[38;5;46m\]\u\[\033[39m\]@localhost \[\033[39m\]\w \[\033[0m\]\$ "
export HOME=/public
export TERM=xterm-256color
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes

INSTALLING=false
FAILSAFE=false

# Parse internal flags
while [ $# -gt 0 ]; do
    case "$1" in
        --installing)
            INSTALLING=true
            shift
            ;;
        --failsafe)
            FAILSAFE=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

# If a command was supplied, execute it and exit
# without it Executor will break
if [ "$INSTALLING" != true ] && [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; then
    exec "$@"
fi

# إصلاح postinst scripts غير المتوافقة مع PRoot
for pkg in "libc6:arm64" "libc6:armhf" "libc6" "libc-bin"; do
    script="/var/lib/dpkg/info/${pkg}.postinst"
    if [ -f "$script" ] && grep -q "busybox\|debconf/frontend" "$script" 2>/dev/null; then
        echo "exit 0" > "$script"
    fi
done
dpkg --configure -a --force-all 2>/dev/null || true

required_packages="bash tzdata wget curl"
missing_packages=""

for pkg in $required_packages; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        missing_packages="$missing_packages $pkg"
    fi
done

if [ -n "$missing_packages" ]; then
    echo -e "\e[34;1m[*] \e[0mInstalling important packages\e[0m"
    apt-get update -qq && apt-get upgrade -y -qq
    apt-get install -y -qq $missing_packages
    if [ $? -eq 0 ]; then
        echo -e "\e[32;1m[+] \e[0mSuccessfully installed\e[0m"
    fi
    echo -e "\e[34m[*] \e[0mUse \e[32mapt\e[0m to install new packages\e[0m"
fi


if [ ! -f /linkerconfig/ld.config.txt ]; then
    mkdir -p /linkerconfig
    touch /linkerconfig/ld.config.txt
fi


if [ "$INSTALLING" = true ]; then
    echo "Configuring timezone..."

    export TZ="UTC"

    if [ -n "$ANDROID_TZ" ] && [ -f "/usr/share/zoneinfo/$ANDROID_TZ" ]; then
        ln -sf "/usr/share/zoneinfo/$ANDROID_TZ" /etc/localtime
        echo "$ANDROID_TZ" > /etc/timezone
        echo "Timezone set to: $ANDROID_TZ"
    else
        echo "Failed to detect timezone, defaulting to UTC"
        ln -sf /usr/share/zoneinfo/UTC /etc/localtime
        echo "UTC" > /etc/timezone
    fi

    # إصلاح libc6 عند التثبيت الأول
    for pkg in "libc6:arm64" "libc6:armhf" "libc6" "libc-bin"; do
        script="/var/lib/dpkg/info/${pkg}.postinst"
        if [ -f "$script" ]; then
            echo "exit 0" > "$script"
        fi
    done
    dpkg --configure -a --force-all 2>/dev/null || true

    mkdir -p "$PREFIX/.configured"

    if [ ! -f "$HOME/.bashrc" ]; then
       touch "$HOME/.bashrc" && chmod 644 "$HOME/.bashrc"
    fi

    echo "Installation completed."
    exit 0
fi



    echo "$$" > "$PREFIX/pid"
    chmod +x "$PREFIX/axs"

    if [ ! -e "$PREFIX/ubuntu/etc/acode_motd" ]; then
        cat <<EOF > "$PREFIX/ubuntu/etc/acode_motd"
Welcome to Ubuntu in Acode!

Working with packages:

 - Search:  apt search <query>
 - Install: apt install <package>
 - Uninstall: apt remove <package>
 - Upgrade: apt update && apt upgrade

EOF
    fi

    # Create acode CLI tool
    if [ ! -e "$PREFIX/ubuntu/usr/local/bin/acode" ]; then
        mkdir -p "$PREFIX/ubuntu/usr/local/bin"
        cat <<'ACODE_CLI' > "$PREFIX/ubuntu/usr/local/bin/acode"
#!/bin/bash
# acode - Open files/folders in Acode editor
# Uses OSC escape sequences to communicate with the Acode terminal

usage() {
    echo "Usage: acode [file/folder...]"
    echo ""
    echo "Open files or folders in Acode editor."
    echo ""
    echo "Examples:"
    echo "  acode file.txt      # Open a file"
    echo "  acode .             # Open current folder"
    echo "  acode ~/project     # Open a folder"
    echo "  acode -h, --help    # Show this help"
}

get_abs_path() {
    local path="$1"
    local abs_path=""

    if command -v realpath >/dev/null 2>&1; then
        abs_path=$(realpath -- "$path" 2>/dev/null)
    fi

    if [[ -z "$abs_path" ]]; then
        if [[ -d "$path" ]]; then
            abs_path=$(cd -- "$path" 2>/dev/null && pwd -P)
        elif [[ -e "$path" ]]; then
            local dir_name file_name
            dir_name=$(dirname -- "$path")
            file_name=$(basename -- "$path")
            abs_path="$(cd -- "$dir_name" 2>/dev/null && pwd -P)/$file_name"
        elif [[ "$path" == /* ]]; then
            abs_path="$path"
        else
            abs_path="$PWD/$path"
        fi
    fi

    echo "$abs_path"
}

open_in_acode() {
    local path=$(get_abs_path "$1")
    local type="file"
    [[ -d "$path" ]] && type="folder"
    
    printf '\e]7777;open;%s;%s\a' "$type" "$path"
}

if [[ $# -eq 0 ]]; then
    open_in_acode "."
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -e "$arg" ]]; then
                open_in_acode "$arg"
            else
                echo "Error: '$arg' does not exist" >&2
                exit 1
            fi
            ;;
    esac
done
ACODE_CLI
        chmod +x "$PREFIX/ubuntu/usr/local/bin/acode"
    fi

    # Create initrc if it doesn't exist
if [ ! -e "$PREFIX/ubuntu/initrc" ]; then
    cat <<'EOF' > "$PREFIX/ubuntu/initrc"
# Source rc files if they exist

if [ -f "/etc/profile" ]; then
    source "/etc/profile"
fi

# Environment setup
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/share/bin:/usr/share/sbin:/usr/local/bin:/usr/local/sbin
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes

export HOME=/public
export TERM=xterm-256color 
SHELL=/bin/bash
export PIP_BREAK_SYSTEM_PACKAGES=1

_shorten_path() {
    local path="$PWD"
    
    if [[ "$HOME" != "/" && "$path" == "$HOME" ]]; then
        echo "~"
        return
    elif [[ "$HOME" != "/" && "$path" == "$HOME/"* ]]; then
        path="~${path#$HOME}"
    fi
    
    [[ "$path" == "~" ]] && echo "~" && return
    
    local parts result=""
    IFS='/' read -ra parts <<< "$path"
    local len=${#parts[@]}
    
    for ((i=0; i<len; i++)); do
        [[ -z "${parts[i]}" ]] && continue
        if [[ $i -lt $((len-1)) ]]; then
            result+="${parts[i]:0:1}/"
        else
            result+="${parts[i]}"
        fi
    done
    
    [[ "$path" == /* ]] && echo "/$result" || echo "$result"
}

PROMPT_COMMAND='_PS1_PATH=$(_shorten_path); _PS1_EXIT=$?'

if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

if [ -f /etc/bash.bashrc ]; then
    source /etc/bash.bashrc
fi

if [ -s /etc/acode_motd ]; then
    cat /etc/acode_motd
fi

check_binary_execution() {
    local cmd="$1"
    local cmd_path=""

    [[ -z "$cmd" ]] && return

    if [[ "$cmd" == */* ]]; then
        cmd_path="$(realpath "$cmd" 2>/dev/null)"
    else
        cmd_path="$(command -v "$cmd" 2>/dev/null)"
        if [[ -n "$cmd_path" ]]; then
            cmd_path="$(realpath "$cmd_path" 2>/dev/null)"
        fi
    fi

    [[ -z "$cmd_path" ]] && return
    [[ ! -f "$cmd_path" ]] && return

    if [[ "$cmd_path" == /storage/* ]] || \
       [[ "$cmd_path" == /sdcard/* ]]; then
        echo -e "\e[1;31m[!] ATTENTION REQUIRED\e[0m

\e[1;31mThe binary is located in:\e[0m
  \e[36m$cmd_path\e[0m

\e[1;31mBinaries cannot be executed reliably from /sdcard or /storage.\e[0m
These locations are backed by Android's external storage layer and do not support normal Linux executable permissions.

Move your project or binary to a directory under:
  \e[1;32m/home/\e[0m

Example:
  \e[1;32mmv myproject ~/myproject\e[0m
  \e[1;32mcd ~/myproject\e[0m

Then run the binary again.
" >&2
    fi
}

_acode_preexec() {
    [[ "$BASH_COMMAND" == trap* ]] && return
    local cmd="${BASH_COMMAND%% *}"
    check_binary_execution "$cmd"
}

__acode_existing_debug_trap="$(trap -p DEBUG 2>/dev/null)"
if [[ -n "${__acode_existing_debug_trap}" ]]; then
    __acode_existing_cmd="$(printf "%s" "${__acode_existing_debug_trap}" | sed -E "s/.*'((.*)?)'.*/\1/")"
else
    __acode_existing_cmd=""
fi

if [[ "${__acode_existing_cmd}" != *"_acode_preexec"* ]]; then
    if [[ -n "${__acode_existing_cmd}" ]]; then
        trap "${__acode_existing_cmd}; _acode_preexec" DEBUG
    else
        trap '_acode_preexec' DEBUG
    fi
fi
unset __acode_existing_debug_trap __acode_existing_cmd

command_not_found_handle() {
    cmd="$1"
    pkg=""
    green="\e[1;32m"
    reset="\e[0m"

    pkg=$(apt-cache search "^$cmd$" 2>/dev/null | awk '{print $1}' | head -n 1)

    if [ -n "$pkg" ]; then
        echo -e "The program '$cmd' is not installed.\nInstall it by executing:\n ${green}apt install $pkg${reset}" >&2
    else
        echo "The program '$cmd' is not installed and no package provides it." >&2
    fi

    return 127
}

EOF
fi

if ! grep -q 'PS1=' "$PREFIX/ubuntu/initrc"; then
    echo 'PS1="\[\033[1;32m\]\u\[\033[0m\]@localhost \[\033[1;34m\]\$_PS1_PATH\[\033[0m\] \[\$([ \$_PS1_EXIT -ne 0 ] && echo \"\033[31m\")\]\$\[\033[0m\] "' >> "$PREFIX/ubuntu/initrc"
fi

chmod +x "$PREFIX/ubuntu/initrc"

if [ "$FAILSAFE" != true ]; then
    "$PREFIX/axs" -c "bash --rcfile /initrc -i"
fi
