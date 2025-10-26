#!/bin/bash
set -e

# WiFi Connect Orchestration Script
# Manages the sequence: network detection → captive portal → configuration → installation → status page

LOG_FILE="/var/log/wifi-connect-orchestrator.log"
STATE_FILE="/var/lib/runtipios/wifi-connect-state"
CONFIG_FILE="/tmp/runtipios-config.json"

exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "==> WiFi Connect Orchestrator Starting..."
echo "==> Date: $(date)"

# Configuration
PORTAL_SSID="${PORTAL_SSID:-RuntipiOS-Setup}"
PORTAL_INTERFACE="${PORTAL_INTERFACE:-wlan0}"
PORTAL_ADDRESS="${PORTAL_ADDRESS:-192.168.42.1}"
PORTAL_DHCP_RANGE="${PORTAL_DHCP_RANGE:-192.168.42.10,192.168.42.100}"
PORTAL_PORT="${PORTAL_PORT:-80}"

# State management
get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "detect"
    fi
}

set_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$1" > "$STATE_FILE"
}

# Network detection
detect_network() {
    echo "==> Detecting network connectivity..."
    
    # Check for ethernet connection
    if ip link show | grep -E "(eth|enp)" | grep -q "state UP"; then
        echo "==> Ethernet connection detected and active"
        return 0
    fi
    
    # Check if WiFi is already configured and connected
    if nmcli -t -f GENERAL.STATE connection show | grep -q "activated"; then
        if nmcli -t -f TYPE connection show --active | grep -q "802-11-wireless"; then
            echo "==> WiFi already configured and connected"
            return 0
        fi
    fi
    
    echo "==> No active network connection detected"
    return 1
}

# Start captive portal
start_captive_portal() {
    echo "==> Starting WiFi Connect captive portal..."
    
    # Stop NetworkManager temporarily
    systemctl stop NetworkManager || true
    
    # Configure wireless interface
    ip link set "$PORTAL_INTERFACE" up
    ip addr flush dev "$PORTAL_INTERFACE"
    ip addr add "$PORTAL_ADDRESS/24" dev "$PORTAL_INTERFACE"
    
    # Configure dnsmasq for DHCP and DNS
    cat > /etc/dnsmasq-wifi-connect.conf << EOF
interface=$PORTAL_INTERFACE
dhcp-range=$PORTAL_DHCP_RANGE,12h
dhcp-option=3,$PORTAL_ADDRESS
dhcp-option=6,$PORTAL_ADDRESS
address=/#/$PORTAL_ADDRESS
no-resolv
log-queries
log-facility=/var/log/dnsmasq-wifi-connect.log
EOF
    
    # Start dnsmasq
    dnsmasq -C /etc/dnsmasq-wifi-connect.conf -d &
    DNSMASQ_PID=$!
    
    # Configure hostapd
    cat > /etc/hostapd-wifi-connect.conf << EOF
interface=$PORTAL_INTERFACE
driver=nl80211
ssid=$PORTAL_SSID
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF
    
    # Start hostapd
    hostapd -B /etc/hostapd-wifi-connect.conf
    
    # Start web portal
    /opt/runtipios/wifi-connect-portal.py &
    PORTAL_PID=$!
    
    echo "==> Captive portal started"
    echo "==> Connect to WiFi network: $PORTAL_SSID"
    echo "==> Portal address: http://$PORTAL_ADDRESS"
    
    # Store PIDs for cleanup
    echo "$DNSMASQ_PID" > /tmp/wifi-connect-dnsmasq.pid
    echo "$PORTAL_PID" > /tmp/wifi-connect-portal.pid
}

# Stop captive portal
stop_captive_portal() {
    echo "==> Stopping captive portal..."
    
    # Kill web portal
    if [ -f /tmp/wifi-connect-portal.pid ]; then
        kill "$(cat /tmp/wifi-connect-portal.pid)" 2>/dev/null || true
        rm -f /tmp/wifi-connect-portal.pid
    fi
    
    # Kill dnsmasq
    if [ -f /tmp/wifi-connect-dnsmasq.pid ]; then
        kill "$(cat /tmp/wifi-connect-dnsmasq.pid)" 2>/dev/null || true
        rm -f /tmp/wifi-connect-dnsmasq.pid
    fi
    
    # Stop hostapd
    pkill hostapd || true
    
    # Restore NetworkManager
    systemctl start NetworkManager || true
    
    echo "==> Captive portal stopped"
}

# Wait for configuration
wait_for_configuration() {
    echo "==> Waiting for user configuration..."
    
    # Wait for config file (max 30 minutes)
    TIMEOUT=1800
    ELAPSED=0
    
    while [ ! -f "$CONFIG_FILE" ] && [ $ELAPSED -lt $TIMEOUT ]; do
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "==> Configuration received"
        return 0
    else
        echo "==> Timeout waiting for configuration"
        return 1
    fi
}

# Apply network configuration
apply_network_config() {
    echo "==> Applying network configuration..."
    
    # Stop captive portal first
    stop_captive_portal
    
    # Parse configuration
    WIFI_SSID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('wifi_ssid', ''))" 2>/dev/null || echo "")
    WIFI_PASS=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('wifi_password', ''))" 2>/dev/null || echo "")
    
    if [ -n "$WIFI_SSID" ] && [ "$WIFI_SSID" != "null" ]; then
        echo "==> Connecting to WiFi network: $WIFI_SSID"
        
        # Wait for NetworkManager to be ready
        sleep 5
        
        # Connect to WiFi
        nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS" || {
            echo "ERROR: Failed to connect to WiFi"
            return 1
        }
        
        # Wait for connection
        sleep 10
        
        # Verify connection
        if nmcli -t -f TYPE connection show --active | grep -q "802-11-wireless"; then
            echo "==> WiFi connected successfully"
            return 0
        else
            echo "ERROR: WiFi connection failed"
            return 1
        fi
    fi
    
    return 0
}

# Start status page
start_status_page() {
    echo "==> Starting status page..."
    
    # Start status page on port 8080
    /opt/runtipios/status-page.py &
    STATUS_PID=$!
    echo "$STATUS_PID" > /tmp/status-page.pid
    
    echo "==> Status page started at http://<ip>:8080"
}

# Stop status page
stop_status_page() {
    echo "==> Stopping status page..."
    
    if [ -f /tmp/status-page.pid ]; then
        kill "$(cat /tmp/status-page.pid)" 2>/dev/null || true
        rm -f /tmp/status-page.pid
    fi
}

# Main orchestration logic
main() {
    STATE=$(get_state)
    echo "==> Current state: $STATE"
    
    case "$STATE" in
        detect)
            if detect_network; then
                echo "==> Network available, proceeding to installation"
                set_state "install"
            else
                echo "==> Starting captive portal mode"
                set_state "portal"
                start_captive_portal
                
                if wait_for_configuration; then
                    set_state "configure"
                    if apply_network_config; then
                        set_state "install"
                    else
                        echo "ERROR: Network configuration failed"
                        exit 1
                    fi
                else
                    echo "ERROR: Configuration timeout"
                    exit 1
                fi
            fi
            
            # Proceed to installation
            if [ "$(get_state)" = "install" ]; then
                echo "==> Proceeding to Runtipi installation"
                # Start status page
                start_status_page
                /opt/runtipios/install-runtipi.sh
                set_state "complete"
                # Keep status page running for viewing
                sleep 300  # Keep it running for 5 minutes
                stop_status_page
            fi
            ;;
            
        portal)
            echo "==> Already in portal mode, waiting for configuration..."
            if wait_for_configuration; then
                set_state "configure"
                apply_network_config
                set_state "install"
                start_status_page
                /opt/runtipios/install-runtipi.sh
                set_state "complete"
                sleep 300
                stop_status_page
            fi
            ;;
            
        complete)
            echo "==> Configuration already complete"
            exit 0
            ;;
            
        *)
            echo "==> Unknown state: $STATE"
            set_state "detect"
            exec "$0"
            ;;
    esac
}

# Cleanup on exit
cleanup() {
    echo "==> Cleaning up..."
    stop_captive_portal
}

trap cleanup EXIT

main "$@"
