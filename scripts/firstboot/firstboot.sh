#!/bin/bash
set -e

# RuntipiOS First Boot Configuration Script
# This script runs on the first boot to configure the system using WiFi Connect

LOG_FILE="/var/log/runtipios-firstboot.log"
CONFIGURED_FLAG="/var/lib/runtipios/configured"

exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "==> RuntipiOS First Boot Configuration Starting..."
echo "==> Date: $(date)"

# Check if already configured
if [ -f "$CONFIGURED_FLAG" ]; then
    echo "==> System already configured, exiting..."
    exit 0
fi

# Wait for system to be ready
sleep 5

# Use WiFi Connect orchestrator for configuration
echo "==> Starting WiFi Connect orchestration..."
/opt/runtipios/wifi-connect-orchestrator.sh

# Mark as configured
mkdir -p "$(dirname "$CONFIGURED_FLAG")"
touch "$CONFIGURED_FLAG"
echo "==> First boot configuration complete!"

# Display Runtipi information
if [ -f /opt/runtipi/state/runtipi.env ]; then
    echo ""
    echo "======================================"
    echo "RuntipiOS Configuration Complete!"
    echo "======================================"
    echo ""
    echo "Runtipi is installed and will be available at:"
    IP_ADDR=$(hostname -I | awk '{print $1}')
    echo "  http://${IP_ADDR}"
    echo "  http://localhost"
    echo ""
    echo "Please reboot the system to complete the setup."
    echo "======================================"
fi

exit 0
