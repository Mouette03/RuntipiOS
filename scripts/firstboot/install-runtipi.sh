#!/bin/bash
set -e

# Install and configure Runtipi

CONFIG_FILE="/tmp/runtipios-config.json"
RUNTIPI_DIR="/opt/runtipi"

echo "==> Installing Runtipi..."

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found!"
    exit 1
fi

# Parse configuration
USERNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['username'])")
PASSWORD=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['password'])")
WIFI_SSID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('wifi_ssid', ''))")
WIFI_PASS=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('wifi_password', ''))")

# Create user
echo "==> Creating user: $USERNAME"
if ! id "$USERNAME" > /dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,docker "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    
    # Allow sudo without password for docker commands
    echo "$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose" >> /etc/sudoers.d/runtipi-user
fi

# Configure WiFi if needed
if [ -n "$WIFI_SSID" ] && [ "$WIFI_SSID" != "null" ]; then
    echo "==> Configuring WiFi..."
    
    # Create NetworkManager connection
    nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS" || {
        echo "WARNING: Failed to connect to WiFi"
    }
fi

# Install Runtipi
echo "==> Downloading Runtipi..."
if [ ! -d "$RUNTIPI_DIR" ]; then
    mkdir -p "$RUNTIPI_DIR"
    cd "$RUNTIPI_DIR"
    
    # Clone Runtipi repository
    git clone https://github.com/runtipi/runtipi.git "$RUNTIPI_DIR" || {
        echo "ERROR: Failed to clone Runtipi repository"
        exit 1
    }
    
    # Set permissions
    chown -R "$USERNAME:$USERNAME" "$RUNTIPI_DIR"
fi

# Run Runtipi installation
echo "==> Running Runtipi setup..."
cd "$RUNTIPI_DIR"
sudo -u "$USERNAME" bash -c "cd $RUNTIPI_DIR && ./scripts/install.sh" || {
    echo "WARNING: Runtipi installation encountered issues"
}

# Start Runtipi
echo "==> Starting Runtipi..."
sudo -u "$USERNAME" bash -c "cd $RUNTIPI_DIR && ./scripts/start.sh" || {
    echo "WARNING: Runtipi failed to start"
}

# Create systemd service for Runtipi
cat > /etc/systemd/system/runtipi.service << EOF
[Unit]
Description=Runtipi Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=$USERNAME
WorkingDirectory=$RUNTIPI_DIR
ExecStart=$RUNTIPI_DIR/scripts/start.sh
ExecStop=$RUNTIPI_DIR/scripts/stop.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable runtipi.service

# Display connection information
IP_ADDR=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================="
echo "Runtipi Installation Complete!"
echo "============================================="
echo ""
echo "Runtipi is accessible at:"
echo "  http://$IP_ADDR"
echo "  http://localhost"
echo ""
echo "SSH access:"
echo "  Username: $USERNAME"
echo "  IP Address: $IP_ADDR"
echo ""
echo "============================================="

# Create a login message
cat > /etc/motd << EOF

============================================
       Welcome to RuntipiOS!
============================================

Runtipi is accessible at:
  http://$IP_ADDR
  http://localhost

For support, visit: https://github.com/runtipi/runtipi

============================================

EOF

echo "==> Runtipi installation complete!"
