#!/bin/bash
# Création des fichiers de service - Version Chroot-safe
set -e
exec > >(tee -a /var/log/setup-services.log) 2>&1

echo "Création des fichiers de service systemd"

cat > /etc/systemd/system/expand-rootfs.service << 'SERVICEEOF'
[Unit]
Description=Expand Root Filesystem on First Boot
ConditionPathExists=!/etc/expand-rootfs-done
[Service]
Type=oneshot
ExecStart=/bin/bash -c "parted /dev/mmcblk0 resizepart 2 100% && resize2fs /dev/mmcblk0p2 && touch /etc/expand-rootfs-done"
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
SERVICEEOF

cat > /etc/systemd/system/unblock-rfkill.service << 'RFKILLEOF'
[Unit]
Description=Unblock WiFi rfkill at boot
[Service]
Type=oneshot
ExecStart=/usr/sbin/rfkill unblock all
[Install]
WantedBy=multi-user.target
RFKILLEOF

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

cat > /etc/systemd/system/runtipi-installer.service << 'RUNTIPIEOF'
[Unit]
Description=Runtipi Automatic Installer
[Service]
Type=oneshot
ExecStart=/bin/bash -c "curl -L https://setup.runtipi.io | bash"
TimeoutStartSec=1800
RUNTIPIEOF

echo "Création des fichiers de service terminée."
