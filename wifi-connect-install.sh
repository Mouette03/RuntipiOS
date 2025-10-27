#!/bin/bash
# Script d'installation de Balena WiFi-Connect

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "======================================"
log "Installation de WiFi-Connect"
log "======================================"

# Charger la configuration
if [ -f /tmp/config.yml ]; then
    eval $(grep -E "^\s*version:" /tmp/config.yml | grep wifi_connect -A 1 | tail -1 | sed 's/^[[:space:]]*version:[[:space:]]*/WIFI_CONNECT_VERSION=/' | sed 's/"//g')
    eval $(grep -E "^\s*ssid:" /tmp/config.yml | sed 's/^[[:space:]]*ssid:[[:space:]]*/WIFI_CONNECT_SSID=/' | sed 's/"//g')
fi

WIFI_CONNECT_VERSION=${WIFI_CONNECT_VERSION:-"4.4.7"}
WIFI_CONNECT_SSID=${WIFI_CONNECT_SSID:-"RuntipiOS-Setup"}
ARCH="aarch64"

# Déterminer l'architecture
if [ "$(uname -m)" = "armv7l" ]; then
    ARCH="armv7hf"
fi

log "Version: ${WIFI_CONNECT_VERSION}"
log "SSID: ${WIFI_CONNECT_SSID}"
log "Architecture: ${ARCH}"

# Télécharger WiFi-Connect
log "Téléchargement de WiFi-Connect..."
DOWNLOAD_URL="https://github.com/balena-os/wifi-connect/releases/download/v${WIFI_CONNECT_VERSION}/wifi-connect-v${WIFI_CONNECT_VERSION}-linux-${ARCH}.tar.gz"

wget -O /tmp/wifi-connect.tar.gz "$DOWNLOAD_URL"

# Extraire
log "Extraction..."
tar -xzf /tmp/wifi-connect.tar.gz -C /usr/local/bin/
chmod +x /usr/local/bin/wifi-connect

# Créer le répertoire pour l'interface utilisateur
mkdir -p /usr/local/share/wifi-connect/ui

# Télécharger l'interface utilisateur personnalisée (optionnel)
# Pour l'instant, utiliser l'interface par défaut de wifi-connect

log "✓ WiFi-Connect installé"

# Créer le script de vérification de connectivité
log "Création du script de vérification..."
cat > /usr/local/bin/wifi-connect-check.sh << 'EOF'
#!/bin/bash
# Script de vérification de la connectivité réseau

# Vérifier si le fichier de configuration réseau existe
if [ -f /etc/runtipi-configured ]; then
    # Système déjà configuré, ne pas lancer wifi-connect
    exit 0
fi

# Vérifier la connectivité Ethernet
if ip link show eth0 | grep -q "state UP"; then
    # Ethernet connecté, marquer comme configuré et ne pas lancer wifi-connect
    touch /etc/runtipi-configured
    exit 0
fi

# Vérifier la connectivité WiFi
if nmcli -t -f GENERAL.STATE dev show wlan0 | grep -q "100 (connected)"; then
    # WiFi connecté, marquer comme configuré et ne pas lancer wifi-connect
    touch /etc/runtipi-configured
    exit 0
fi

# Pas de connectivité, lancer wifi-connect
exec /usr/local/bin/wifi-connect --portal-ssid "RuntipiOS-Setup" --portal-interface wlan0
EOF

chmod +x /usr/local/bin/wifi-connect-check.sh

log "✓ Script de vérification créé"

# Créer le service systemd
log "Configuration du service systemd..."
cat > /etc/systemd/system/wifi-connect.service << 'EOF'
[Unit]
Description=Balena WiFi Connect
After=NetworkManager.service
Wants=NetworkManager.service
Before=runtipi-installer.service

[Service]
Type=simple
ExecStart=/usr/local/bin/wifi-connect-check.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Activer le service
systemctl daemon-reload
systemctl enable wifi-connect.service

log "✓ Service WiFi-Connect configuré et activé"

# Nettoyer
rm -f /tmp/wifi-connect.tar.gz

log "======================================"
log "Installation de WiFi-Connect terminée"
log "======================================"
