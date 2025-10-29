#!/bin/bash

# Script de customisation du système d'exploitation
# ⚠️ IMPORTANT: Docker sera installé automatiquement par Runtipi

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "======================================"
log "Customisation du système"
log "======================================"

# ============================================================================
# CHARGER LA CONFIGURATION
# ============================================================================

# Fonction pour trouver le fichier config (persistant ou temporaire)
get_config_file() {
    if [ -f /etc/runtipios/config.yml ]; then
        echo /etc/runtipios/config.yml
    elif [ -f /tmp/config.yml ]; then
        echo /tmp/config.yml
    else
        echo /tmp/config.yml  # Défaut
    fi
}

CONFIG_FILE=$(get_config_file)

# Parser le YAML (version simplifiée)
parse_config() {
    local key=$1
    if [ -f "$CONFIG_FILE" ]; then
        grep -E "^\s*${key}:" "$CONFIG_FILE" | sed "s/^[[:space:]]*${key}:[[:space:]]*//g" | sed 's/"//g' | sed "s/'//g"
    fi
}

# Configuration système
HOSTNAME=$(parse_config "hostname")
TIMEZONE=$(parse_config "timezone")
LOCALE=$(parse_config "locale")
KEYBOARD=$(parse_config "keyboard_layout")
DEFAULT_USER=$(parse_config "default_user")
DEFAULT_PASSWORD=$(parse_config "default_password")
WIFI_COUNTRY=$(parse_config "wifi_country")

# Valeurs par défaut
HOSTNAME=${HOSTNAME:-runtipios}
TIMEZONE=${TIMEZONE:-Europe/Paris}
LOCALE=${LOCALE:-fr_FR.UTF-8}
KEYBOARD=${KEYBOARD:-fr}
DEFAULT_USER=${DEFAULT_USER:-runtipi}
DEFAULT_PASSWORD=${DEFAULT_PASSWORD:-runtipi}
WIFI_COUNTRY=${WIFI_COUNTRY:-FR}

log "Configuration du système:"
log " - Hostname: $HOSTNAME"
log " - Timezone: $TIMEZONE"
log " - Locale: $LOCALE"
log " - Clavier: $KEYBOARD"
log " - User: $DEFAULT_USER"
log " - WiFi Country: $WIFI_COUNTRY"

log ""
log "╔════════════════════════════════════════════════════╗"
log "║                                                    ║"
log "║   ████████████████████  RuntipiOS  ████████████   ║"
log "║   ███████  Image Raspberry Pi OS  ███████████     ║"
log "║   ████  Optimisée pour Runtipi + WiFi-Connect ██  ║"
log "║                                                    ║"
log "║         Hostname: $HOSTNAME"
log "║         Timezone: $TIMEZONE"
log "║         Locale: $LOCALE"
log "║         Clavier: $KEYBOARD"
log "║                                                    ║"
log "╚════════════════════════════════════════════════════╝"
log ""

# ============================================================================
# CONFIGURER LE HOSTNAME
# ============================================================================

log "Configuration du hostname..."
echo "$HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts

# ============================================================================
# CONFIGURER LE TIMEZONE
# ============================================================================

log "Configuration du timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo "$TIMEZONE" > /etc/timezone

# ============================================================================
# CONFIGURER LA LOCALE
# ============================================================================

log "Configuration de la locale..."
sed -i "s/^# *${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
update-locale LANG=$LOCALE

# ============================================================================
# CONFIGURER LE CLAVIER - CORRECTION CRITIQUE #1
# ============================================================================

log "Configuration du clavier: $KEYBOARD..."

mkdir -p /etc/default

cat > /etc/default/keyboard << KEYBOARDEOF
XKBMODEL="pc105"
XKBLAYOUT="$KEYBOARD"
XKBVARIANT="latin9"
BACKSPACE="guess"
KEYBOARDEOF

# Charger la configuration
setupcon 2>/dev/null || log "setupcon non disponible (non-critique)"
localctl set-keymap "$KEYBOARD" 2>/dev/null || log "localctl non disponible (non-critique)"

log "✓ Clavier configuré: $KEYBOARD"

# ============================================================================
# DÉSACTIVER LE WIZARD DE PREMIÈRE INSTALLATION
# ============================================================================

log "Désactivation du wizard de première installation..."

# Supprimer le script piwiz (wizard graphique)
rm -f /etc/xdg/autostart/piwiz.desktop

# Marquer la configuration initiale comme terminée
touch /etc/pi-setup-complete

# Désactiver userconf-pi (qui demande de renommer l'utilisateur)
systemctl disable userconfig.service 2>/dev/null || true
systemctl mask userconfig.service 2>/dev/null || true

# Supprimer le fichier userconf qui déclenche le wizard
rm -f /boot/firmware/userconf.txt
rm -f /boot/firmware/userconf

log "✓ Wizard de première installation désactivé"

# ============================================================================
# CONFIGURER LE PAYS WIFI (OBLIGATOIRE POUR DÉBLOQUER RFKILL)
# ============================================================================

log "Configuration du pays WiFi: $WIFI_COUNTRY..."

# Méthode 1: Via raspi-config (non-interactif)
if command -v raspi-config &>/dev/null; then
    raspi-config nonint do_wifi_country "$WIFI_COUNTRY" || log "raspi-config wifi country failed (non-critique)"
fi

# Méthode 2: Configuration directe dans wpa_supplicant
mkdir -p /etc/wpa_supplicant
cat > /etc/wpa_supplicant/wpa_supplicant.conf << WPAEOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$WIFI_COUNTRY
WPAEOF

# Méthode 3: Configuration via rfkill et iw
# Débloquer le WiFi
rfkill unblock wifi 2>/dev/null || log "rfkill unblock wifi failed (non-critique)"
rfkill unblock wlan 2>/dev/null || log "rfkill unblock wlan failed (non-critique)"

# Méthode 4: Configuration via NetworkManager
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi-country.conf << NMEOF
[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.powersave=2
NMEOF

# Méthode 5: Ajouter au fichier de configuration du kernel
if [ -f /boot/firmware/config.txt ]; then
    # Supprimer les anciennes configurations
    sed -i '/^country=/d' /boot/firmware/config.txt
    # Ajouter la nouvelle
    echo "country=$WIFI_COUNTRY" >> /boot/firmware/config.txt
fi

log "✓ Pays WiFi configuré: $WIFI_COUNTRY"

# ============================================================================
# DÉBLOQUER RFKILL DE MANIÈRE PERMANENTE
# ============================================================================

log "Déblocage permanent de rfkill..."

# Créer un service systemd pour débloquer rfkill au boot
cat > /etc/systemd/system/unblock-rfkill.service << 'RFKILLEOF'
[Unit]
Description=Unblock WiFi rfkill
After=network-pre.target
Before=network.target wifi-connect.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/rfkill unblock wifi
ExecStart=/usr/sbin/rfkill unblock wlan
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
RFKILLEOF

systemctl enable unblock-rfkill.service

log "✓ Service rfkill unblock créé et activé"

# ============================================================================
# METTRE À JOUR LES PAQUETS
# ============================================================================

log "Mise à jour des paquets..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# ============================================================================
# INSTALLER LES PAQUETS NÉCESSAIRES - SANS DOCKER
# ============================================================================

log "Installation des paquets..."

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    curl \
    wget \
    vim \
    nano \
    htop \
    iotop \
    ncdu \
    avahi-daemon \
    avahi-utils \
    network-manager \
    dnsmasq \
    python3 \
    python3-pip \
    python3-yaml \
    ca-certificates \
    gnupg \
    lsb-release \
    openssh-server \
    rfkill \
    wireless-tools \
    wpasupplicant \
    iw \
    jq

log "✓ Paquets installés"

# ============================================================================
# ⚠️ DOCKER SERA INSTALLÉ PAR RUNTIPI AUTOMATIQUEMENT
# ============================================================================

log "Note: Docker sera installé automatiquement par Runtipi au premier démarrage"

# ============================================================================
# CRÉER L'UTILISATEUR
# ============================================================================

log "Création de l'utilisateur $DEFAULT_USER..."

if ! id "$DEFAULT_USER" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,netdev "$DEFAULT_USER"
    echo "$DEFAULT_USER:$DEFAULT_PASSWORD" | chpasswd
    log "✓ Utilisateur créé"
else
    log "Utilisateur déjà existant"
    # Ajouter au groupe netdev si nécessaire
    usermod -aG netdev "$DEFAULT_USER" 2>/dev/null || true
fi

# ============================================================================
# CONFIGURER SSH
# ============================================================================

log "Configuration de SSH..."

mkdir -p /home/$DEFAULT_USER/.ssh
chmod 700 /home/$DEFAULT_USER/.ssh
chown -R $DEFAULT_USER:$DEFAULT_USER /home/$DEFAULT_USER/.ssh

# Activer l'authentification par mot de passe
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Permettre la connexion avec vide (pour clé SSH sans mot de passe)
sed -i 's/^#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Autoriser l'authentification par clé publique
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Relancer SSH pour appliquer les modifications
systemctl restart ssh

log "✓ SSH configuré"

# ============================================================================
# CONFIGURER SUDO SANS MOT DE PASSE POUR L'UTILISATEUR
# ============================================================================

log "Configuration de sudo pour l'utilisateur $DEFAULT_USER..."

# Créer le fichier sudoers pour runtipi
cat > /etc/sudoers.d/$DEFAULT_USER << SUDOEOF
$DEFAULT_USER ALL=(ALL) NOPASSWD: ALL
SUDOEOF

chmod 440 /etc/sudoers.d/$DEFAULT_USER

log "✓ Sudo configuré pour $DEFAULT_USER"

# ============================================================================
# CRÉER LES FICHIERS DE CONFIGURATION POUR WIFI-CONNECT ET RUNTIPI
# ============================================================================

log "Création des fichiers de configuration..."

# Créer le répertoire de configuration
mkdir -p /etc/runtipios

# Copier la configuration (persistante)
if [ -f /tmp/config.yml ]; then
    cp /tmp/config.yml /etc/runtipios/config.yml
fi

# Créer un fichier de configuration pour Runtipi
cat > /etc/runtipios/config.yml << 'CONFEOF'
# Configuration RuntipiOS
system:
  hostname: runtipios
  timezone: Europe/Paris
  locale: fr_FR.UTF-8
  keyboard_layout: fr

runtipi:
  version: v4.5.3
  auto_install: true

wifi_connect:
  ssid: RuntipiOS-Setup
  version: 4.4.6
CONFEOF

log "✓ Fichiers de configuration créés"

# ============================================================================
# CRÉER LE MOTD (MESSAGE DE BIENVENUE)
# ============================================================================

log "Création du message de bienvenue..."

cat > /etc/motd << 'MOTDEOF'
╔════════════════════════════════════════════════════╗
║                                                    ║
║        Bienvenue sur RuntipiOS ! 🎉               ║
║                                                    ║
║    Système Raspberry Pi OS optimisé pour Runtipi  ║
║        avec configuration WiFi automatique        ║
║                                                    ║
║  Accès:                                            ║
║  - Runtipi: http://runtipios.local:3000           ║
║  - SSH: ssh runtipi@runtipios.local               ║
║                                                    ║
║  Documentation: https://runtipi.io                ║
║                                                    ║
╚════════════════════════════════════════════════════╝
MOTDEOF

log "✓ Message de bienvenue configuré"

# ============================================================================
# FINALISER LA CONFIGURATION
# ============================================================================

log "Finalisation de la configuration..."

# Nettoyage
apt-get clean
apt-get autoclean

# Générer les clés SSH du serveur si nécessaire
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi

log ""
log "╔════════════════════════════════════════════════════╗"
log "║                                                    ║"
log "║     ✓ Customisation du système terminée !         ║"
log "║                                                    ║"
log "║  Au premier démarrage:                            ║"
log "║  1. WiFi-Connect apparaîtra si pas de réseau     ║"
log "║  2. Runtipi s'installera automatiquement         ║"
log "║  3. L'accès web sera disponible après ~5-10 min  ║"
log "║                                                    ║"
log "╚════════════════════════════════════════════════════╝"
log ""

log "✓ Configuration terminée avec succès !"