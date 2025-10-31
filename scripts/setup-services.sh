#!/bin/bash
# Script de configuration des services systemd
set -e
exec > >(tee -a /var/log/setup-services.log) 2>&1

echo "Configuration des services système"

# Service pour débloquer le WiFi au démarrage
cat > /etc/systemd/system/unblock-rfkill.service << 'RFKILLEOF'
[Unit]
Description=Unblock WiFi rfkill at boot
[Service]
Type=oneshot
ExecStart=/usr/sbin/rfkill unblock all
[Install]
WantedBy=multi-user.target
RFKILLEOF

# Service "intelligent" qui se lance au premier boot
cat > /etc/systemd/system/runtipios-first-boot.service << 'BOOTSVCEOF'
[Unit]
Description=RuntipiOS First Boot Logic
Wants=network-online.target
After=network-online.target
[Service]
ExecStart=/usr/local/bin/runtipios-first-boot.sh
Restart=on-failure
[Install]
WantedBy=multi-user.target
BOOTSVCEOF

# Service pour installer Runtipi (ne se lance pas tout seul)
cat > /etc/systemd/system/runtipi-installer.service << 'RUNTIPIEOF'
[Unit]
Description=Runtipi Automatic Installer
[Service]
Type=oneshot
ExecStart=/bin/bash -c "curl -L https://setup.runtipi.io | bash"
TimeoutStartSec=1800
RUNTIPIEOF

# Activation des services
systemctl daemon-reload
systemctl enable unblock-rfkill.service
systemctl enable runtipios-first-boot.service
systemctl enable avahi-daemon.service

# Configuration des mises à jour automatiques si le paquet est listé
if [ -f /etc/runtipios/config.yml ] && yq -e '.packages.install[] | select(. == "unattended-upgrades")' /etc/runtipios/config.yml > /dev/null; then
    dpkg-reconfigure -plow unattended-upgrades
fi

echo "Configuration des services terminée."
