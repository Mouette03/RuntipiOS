#!/bin/bash
set -e

# This script runs inside the chroot environment to set up the system

echo "==> Configuring APT sources..."
cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

echo "==> Updating package lists..."
apt-get update

echo "==> Installing required packages..."
# Parse packages from config
python3 - << 'PYEOF'
import yaml
with open('/tmp/build-config.yml', 'r') as f:
    config = yaml.safe_load(f)
packages = ' '.join(config['packages'])
print(packages)
PYEOF

PACKAGES=$(python3 - << 'PYEOF'
import yaml
with open('/tmp/build-config.yml', 'r') as f:
    config = yaml.safe_load(f)
packages = ' '.join(config['packages'])
print(packages)
PYEOF
)

DEBIAN_FRONTEND=noninteractive apt-get install -y ${PACKAGES}

echo "==> Installing Python dependencies for installer..."
pip3 install --break-system-packages pyyaml || pip3 install pyyaml

echo "==> Configuring system..."
# Set hostname
echo "runtipios" > /etc/hostname

# Configure network
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback
EOF

# Enable NetworkManager
systemctl enable NetworkManager || true

# Enable SSH
systemctl enable ssh || true

echo "==> Installing first-boot configuration service..."
# Copy first-boot scripts
mkdir -p /opt/runtipios
cp -r /tmp/firstboot/* /opt/runtipios/ 2>/dev/null || true
cp -r /tmp/installer/* /opt/runtipios/ 2>/dev/null || true

# Create systemd service for first boot configuration
cat > /etc/systemd/system/runtipios-firstboot.service << 'EOF'
[Unit]
Description=RuntipiOS First Boot Configuration
After=network.target
ConditionPathExists=!/var/lib/runtipios/configured

[Service]
Type=oneshot
ExecStart=/opt/runtipios/firstboot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable runtipios-firstboot.service || true

echo "==> Creating boot configuration marker..."
mkdir -p /var/lib/runtipios

echo "==> Cleaning up..."
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*

echo "==> Chroot setup complete!"
