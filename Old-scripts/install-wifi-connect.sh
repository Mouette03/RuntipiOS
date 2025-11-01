#!/bin/bash
# Script d'installation de WiFi-Connect - Version Finale Absolue
set -e
exec > >(tee -a /var/log/install-wifi-connect.log) 2>&1

echo "Installation de Balena WiFi-Connect"

# --- Arguments ---
WIFI_CONNECT_VERSION=$1
RASPIOS_ARCH=$2
PORTAL_SSID=$3

TARGET_ARCH=""
case "$RASPIOS_ARCH" in
    "armhf") TARGET_ARCH="armv7hf" ;;
    "arm64") TARGET_ARCH="aarch64" ;;
esac

DOWNLOAD_URL="https://github.com/balena-os/wifi-connect/releases/download/v${WIFI_CONNECT_VERSION}/wifi-connect-v${WIFI_CONNECT_VERSION}-linux-${TARGET_ARCH}.tar.gz"

cd /tmp

echo "Téléchargement de WiFi-Connect depuis ${DOWNLOAD_URL}..."
curl -L --fail "$DOWNLOAD_URL" -o wc.tar.gz

echo "Extraction de l'archive dans un répertoire temporaire..."
# --- CORRECTION DE LA LOGIQUE D'INSTALLATION ---
# Créer un répertoire temporaire pour une extraction propre
mkdir -p /tmp/wc-extract
tar -xvzf wc.tar.gz -C /tmp/wc-extract

# Déplacer le binaire au bon endroit
echo "Installation du binaire wifi-connect..."
mv /tmp/wc-extract/wifi-connect /usr/local/bin/
chmod +x /usr/local/bin/wifi-connect

# Déplacer le répertoire de l'interface utilisateur au bon endroit
echo "Installation de l'interface utilisateur..."
mkdir -p /etc/runtipios
mv /tmp/wc-extract/ui /etc/runtipios/

# Nettoyage des fichiers temporaires
echo "Nettoyage..."
rm -rf /tmp/wc-extract
rm -f /tmp/wc.tar.gz

# --- Création du script de premier démarrage ---
# Le répertoire UI est maintenant /etc/runtipios/ui
UI_DIR="/etc/runtipios/ui"

cat > /usr/local/bin/runtipios-first-boot.sh << BOOTSCRIPT
#!/bin/bash
if [ -f /etc/runtipios/configured ]; then exit 0; fi
if nmcli -t g | grep -q "full"; then
    touch /etc/runtipios/configured
    systemctl start runtipi-installer.service
    systemctl disable --now runtipios-first-boot.service
else
    exec /usr/local/bin/wifi-connect --portal-ssid "${PORTAL_SSID}" --ui-directory "${UI_DIR}"
fi
BOOTSCRIPT
chmod +x /usr/local/bin/runtipios-first-boot.sh

echo "Installation de WiFi-Connect terminée avec succès."
