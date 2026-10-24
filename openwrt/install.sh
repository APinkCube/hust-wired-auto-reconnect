#!/bin/sh
set -eu

BINARY=${1:-./hust-network-login}
INIT_SCRIPT=${2:-./hust-login.init}
INSTALL_ROOT=/usr/bin
CONFIG=/etc/hust-network-login.conf
SERVICE=/etc/init.d/hust-login

if [ "$(id -u)" != "0" ]; then
    echo "Please run this installer as root on the OpenWrt router." >&2
    exit 1
fi

if [ ! -f "$BINARY" ]; then
    echo "Binary not found: $BINARY" >&2
    exit 1
fi

if [ ! -f "$INIT_SCRIPT" ]; then
    echo "Init script not found: $INIT_SCRIPT" >&2
    exit 1
fi

cp "$BINARY" "$INSTALL_ROOT/hust-network-login"
chmod 0755 "$INSTALL_ROOT/hust-network-login"
cp "$INIT_SCRIPT" "$SERVICE"
chmod 0755 "$SERVICE"

if [ ! -s "$CONFIG" ]; then
    printf 'HUST student ID: '
    IFS= read -r username
    printf 'Campus network password (input hidden): '
    stty -echo
    trap 'stty echo' EXIT HUP INT TERM
    IFS= read -r password
    stty echo
    trap - EXIT HUP INT TERM
    printf '\n'

    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "Student ID and password must not be empty." >&2
        exit 1
    fi

    umask 077
    printf '%s\n%s\n' "$username" "$password" > "$CONFIG"
    unset username password
else
    echo "Keeping existing credential file: $CONFIG"
fi

chmod 0600 "$CONFIG"
"$SERVICE" enable
"$SERVICE" restart

echo "Installed and started hust-network-login."
echo "Check logs with: logread -e hust-network-login"
