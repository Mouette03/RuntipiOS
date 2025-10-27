#!/bin/bash
# Script de configuration des services systemd

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "======================================"
log "Configuration des services"
log "======================================"

# Service d'installation automatique de Runtipi
log "Configuration du service Runtipi..."
cat > /etc/systemd/system/runtipi-installer.service << 'EOF'
[Unit]
Description=Runtipi Auto-Installer
After=network-online.target wifi-connect.service
Wants=network-online.target
ConditionPathExists=!/etc/runtipi-configured

[Service]
Type=oneshot
ExecStart=/usr/local/bin/install-runtipi.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal
TimeoutStartSec=1800

[Install]
WantedBy=multi-user.target
EOF

# Activer le service
systemctl daemon-reload
systemctl enable runtipi-installer.service

log "✓ Service Runtipi configuré"

# Service de page de statut
if [ -f /etc/runtipios/config.yml ] && grep -q "enable: true" /etc/runtipios/config.yml | grep -A 5 status_page; then
    log "Configuration du service de page de statut..."
    systemctl enable lighttpd
    log "✓ Service de page de statut configuré"
fi

log "======================================"
log "Configuration des services terminée"
log "======================================"
