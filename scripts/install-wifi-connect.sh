#!/bin/bash
# Script d'installation de WiFi-Connect - Version Finale Corrigée
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

# --- CORRECTION DE L'URL ET DE L'EXTENSION ---
DOWNLOAD_URL="https://github.com/balena-os/wifi-connect/releases/download/v${WIFI_CONNECT_VERSION}/wifi-connect-v${WIFI_CONNECT_VERSION}-linux-${TARGET_ARCH}.tar.gz"

cd /tmp

echo "Téléchargement de WiFi-Connect depuis ${DOWNLOAD_URL}..."
curl -L --fail "$DOWNLOAD_URL" -o wc.tar.gz

echo "Extraction de l'archive..."
# --- CORRECTION DE LA COMMANDE DE DÉCOMPRESSION ---
tar -xvzf wc.tar.gz -C /usr/local/bin/

mv /usr/local/bin/wifi-connect*/* /usr/local/bin/
chmod +x /usr/local/bin/wifi-connect

# --- Création de l'interface du portail ---
UI_DIR="/etc/runtipios/ui"
mkdir -p "$UI_DIR"
cat > "${UI_DIR}/index.html" << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>RuntipiOS WiFi Setup</title><style>body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background-color:#f4f6f8}.header{background:#fff;padding:20px;text-align:center;border-bottom:1px solid #e0e0e0}.logo{max-width:150px;height:auto}.info-box{background:#fff3cd;border-left:4px solid #ffeeba;padding:15px 20px;margin:20px;border-radius:8px;color:#664d03;text-align:center;font-size:14px}.instructions{padding:0 20px;text-align:center;color:#555}.instructions h2{margin-bottom:10px;color:#333}code{background:#e9ecef;padding:2px 6px;border-radius:4px}</style></head><body><div class="header"><img src="https://runtipi.io/img/logo.png" alt="Runtipi Logo" class="logo"></div><div class="info-box"><strong id="security-alert-title"></strong><br><span id="security-alert-text"></span><code>passwd</code></div><div class="instructions"><h2 id="instruction-title"></h2><p id="instruction-text"></p></div><script>const t={en:{"security-alert-title":"IMPORTANT SECURITY NOTICE","security-alert-text":"After setup, connect via SSH and change the default password by typing the command:","instruction-title":"Configure WiFi","instruction-text":"Please select your WiFi network from the list below and enter the password to connect."},fr:{"security-alert-title":"AVIS DE SÉCURITÉ IMPORTANT","security-alert-text":"Après la configuration, connectez-vous en SSH et changez le mot de passe par défaut avec la commande :","instruction-title":"Configurer le WiFi","instruction-text":"Veuillez sélectionner votre réseau WiFi dans la liste ci-dessous et entrer le mot de passe pour vous connecter."}},n=navigator.language.split("-")[0],o=t[n]||t.en;for(const e in o){const l=document.getElementById(e);l&&(l.innerHTML=o[e])}</script></body></html>
HTMLEOF

# --- Création du script de premier démarrage ---
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

rm -f /tmp/wc.tar.gz
echo "Installation de WiFi-Connect terminée."
