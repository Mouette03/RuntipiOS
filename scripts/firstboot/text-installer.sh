#!/bin/bash
set -e

# Text-based installer using dialog/whiptail

CONFIG_FILE="/tmp/runtipios-config.json"

echo "==> RuntipiOS Text-Based Configuration"

# Check for ethernet
HAS_ETHERNET=false
if ip link show | grep -E "(eth|enp)" > /dev/null 2>&1; then
    HAS_ETHERNET=true
    echo "==> Ethernet connection detected"
else
    echo "==> No ethernet detected, WiFi configuration required"
fi

# Use dialog if available, otherwise use read
if command -v dialog > /dev/null 2>&1; then
    DIALOG=dialog
elif command -v whiptail > /dev/null 2>&1; then
    DIALOG=whiptail
else
    DIALOG=""
fi

if [ -n "$DIALOG" ]; then
    # Use dialog interface
    if [ "$HAS_ETHERNET" = false ]; then
        WIFI_SSID=$($DIALOG --inputbox "Enter WiFi SSID:" 10 60 3>&1 1>&2 2>&3)
        WIFI_PASS=$($DIALOG --passwordbox "Enter WiFi Password:" 10 60 3>&1 1>&2 2>&3)
    fi
    
    SSH_USER=$($DIALOG --inputbox "Enter SSH Username:" 10 60 "runtipi" 3>&1 1>&2 2>&3)
    SSH_PASS=$($DIALOG --passwordbox "Enter SSH Password:" 10 60 3>&1 1>&2 2>&3)
    SSH_PASS_CONFIRM=$($DIALOG --passwordbox "Confirm SSH Password:" 10 60 3>&1 1>&2 2>&3)
    
    if [ "$SSH_PASS" != "$SSH_PASS_CONFIRM" ]; then
        $DIALOG --msgbox "Passwords do not match!" 10 40
        exit 1
    fi
else
    # Use simple read interface
    if [ "$HAS_ETHERNET" = false ]; then
        read -p "Enter WiFi SSID: " WIFI_SSID
        read -sp "Enter WiFi Password: " WIFI_PASS
        echo
    fi
    
    read -p "Enter SSH Username [runtipi]: " SSH_USER
    SSH_USER=${SSH_USER:-runtipi}
    read -sp "Enter SSH Password: " SSH_PASS
    echo
    read -sp "Confirm SSH Password: " SSH_PASS_CONFIRM
    echo
    
    if [ "$SSH_PASS" != "$SSH_PASS_CONFIRM" ]; then
        echo "ERROR: Passwords do not match!"
        exit 1
    fi
fi

# Save configuration as JSON
cat > "$CONFIG_FILE" << EOF
{
    "username": "$SSH_USER",
    "password": "$SSH_PASS",
    "wifi_ssid": "${WIFI_SSID:-null}",
    "wifi_password": "${WIFI_PASS:-null}"
}
EOF

echo "==> Configuration saved successfully!"
