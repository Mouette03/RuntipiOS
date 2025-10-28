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

# Charger la configuration depuis /tmp/config.yml
CONFIG_FILE="/tmp/config.yml"

# Parser le YAML (version simplifiée)
parse_config() {
    local key=$1
    grep -E "^\s*${key}:" "$CONFIG_FILE" | sed "s/^[[:space:]]*${key}:[[:space:]]*//" | sed 's/"//g' | sed "s/'//g"
}

# Configuration système
HOSTNAME=$(parse_config "hostname")
TIMEZONE=$(parse_config "timezone")
LOCALE=$(parse_config "locale")
KEYBOARD=$(parse_config "keyboard_layout")
DEFAULT_USER=$(parse_config "default_user")
DEFAULT_PASSWORD=$(parse_config "default_password")

HOSTNAME=${HOSTNAME:-runtipios}
TIMEZONE=${TIMEZONE:-Europe/Paris}
LOCALE=${LOCALE:-fr_FR.UTF-8}
DEFAULT_USER=${DEFAULT_USER:-runtipi}
DEFAULT_PASSWORD=${DEFAULT_PASSWORD:-runtipi}

log "Configuration du système:"
log "  - Hostname: $HOSTNAME"
log "  - Timezone: $TIMEZONE"
log "  - Locale: $LOCALE"
log "  - User: $DEFAULT_USER"

# Configurer le hostname
log "Configuration du hostname..."
echo "$HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts

# Configurer le timezone
log "Configuration du timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo "$TIMEZONE" > /etc/timezone

# Configurer la locale
log "Configuration de la locale..."
sed -i "s/^# *${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
update-locale LANG=$LOCALE

# Mettre à jour les paquets
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
    openssh-server

log "✓ Paquets installés"

# ============================================================================
# ⚠️ DOCKER SERA INSTALLÉ PAR RUNTIPI AUTOMATIQUEMENT
# ============================================================================
log "Note: Docker sera installé automatiquement par Runtipi au premier démarrage"

# Créer l'utilisateur
log "Création de l'utilisateur $DEFAULT_USER..."
if ! id "$DEFAULT_USER" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo "$DEFAULT_USER"
    echo "$DEFAULT_USER:$DEFAULT_PASSWORD" | chpasswd
    log "✓ Utilisateur créé"
else
    log "Utilisateur déjà existant"
fi

# Configurer SSH
log "Configuration de SSH..."
mkdir -p /home/$DEFAULT_USER/.ssh
chmod 700 /home/$DEFAULT_USER/.ssh
chown -R $DEFAULT_USER:$DEFAULT_USER /home/$DEFAULT_USER/.ssh

# Activer SSH
systemctl enable ssh

# Configurer Avahi (mDNS)
log "Configuration d'Avahi (mDNS)..."
systemctl enable avahi-daemon

# ============================================================================
# NETTOYAGE AGRESSIF POUR ÉCONOMISER DE L'ESPACE
# ============================================================================
log "Nettoyage des paquets..."
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/tmp/*

log "✓ Nettoyage effectué"

# Créer le répertoire de configuration
mkdir -p /etc/runtipios
cp /tmp/config.yml /etc/runtipios/config.yml

# Créer le message du jour (MOTD)
log "Configuration du MOTD..."
cat > /etc/motd << 'EOF'

██████╗ ██╗   ██╗███╗   ██╗████████╗██╗██████╗ ██╗ ██████╗ ███████╗
██╔══██╗██║   ██║████╗  ██║╚══██╔══╝██║██╔══██╗██║██╔═══██╗██╔════╝
██████╔╝██║   ██║██╔██╗ ██║   ██║   ██║██████╔╝██║██║   ██║███████╗
██╔══██╗██║   ██║██║╚██╗██║   ██║   ██║██╔═══╝ ██║██║   ██║╚════██║
██║  ██║╚██████╔╝██║ ╚████║   ██║   ██║██║     ██║╚██████╔╝███████║
╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚══════╝

Bienvenue sur RuntipiOS !

Système Raspberry Pi OS optimisé pour Runtipi
avec configuration WiFi automatique

Accès:
  - Runtipi: http://runtipios.local ou http://$(hostname -I | awk '{print $1}')
  - SSH: ssh runtipi@runtipios.local

Documentation: https://runtipi.io

EOF

# Créer la page de statut web (légère)
log "Création de la page de statut..."
mkdir -p /var/www/html
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RuntipiOS - Statut</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #fff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            max-width: 600px;
            width: 100%;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-align: center;
        }
        .subtitle {
            text-align: center;
            opacity: 0.9;
            margin-bottom: 40px;
        }
        .status {
            background: rgba(255, 255, 255, 0.15);
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        .status-item:last-child {
            border-bottom: none;
        }
        .status-label {
            font-weight: 600;
        }
        .status-value {
            font-family: monospace;
            background: rgba(0, 0, 0, 0.2);
            padding: 5px 10px;
            border-radius: 5px;
        }
        .button {
            display: inline-block;
            background: rgba(255, 255, 255, 0.2);
            color: #fff;
            padding: 12px 24px;
            border-radius: 8px;
            text-decoration: none;
            margin: 10px 5px;
            transition: all 0.3s;
            border: 2px solid rgba(255, 255, 255, 0.3);
        }
        .button:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }
        .buttons {
            display: flex;
            justify-content: center;
            flex-wrap: wrap;
            margin-top: 30px;
        }
        .logo {
            text-align: center;
            margin-bottom: 20px;
            font-size: 4em;
        }
        .info {
            background: rgba(255, 255, 255, 0.1);
            border-left: 4px solid rgba(255, 255, 255, 0.5);
            padding: 15px;
            border-radius: 5px;
            margin-top: 20px;
            font-size: 0.9em;
            line-height: 1.5;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1>RuntipiOS</h1>
        <p class="subtitle">Système prêt pour Runtipi</p>
        
        <div class="status">
            <div class="status-item">
                <span class="status-label">Hostname</span>
                <span class="status-value" id="hostname">runtipios</span>
            </div>
            <div class="status-item">
                <span class="status-label">État</span>
                <span class="status-value" id="status">✓ Prêt</span>
            </div>
        </div>
        
        <div class="buttons">
            <a href="http://runtipios.local" class="button">Accéder à Runtipi</a>
        </div>

        <div class="info">
            <strong>ℹ️ Information:</strong><br>
            Runtipi est en cours d'installation au premier démarrage.<br>
            Cela peut prendre 10-15 minutes. Vérifiez votre connexion réseau.
        </div>
    </div>
</body>
</html>
EOF

# Installer un serveur web léger UNIQUEMENT pour la page de statut
log "Installation du serveur web léger..."
apt-get install -y lighttpd
systemctl enable lighttpd

# Nettoyage final - NE PAS supprimer /tmp/* car les autres scripts en ont besoin !
log "Nettoyage final..."
apt-get clean
# IMPORTANT: Laisser /tmp/ intact pour que WiFi-Connect et autres scripts puissent lire config.yml

log "✓ Customisation terminée"
log "======================================"
log ""
log "✅ Le système est prêt!"
log ""
log "Prochaines étapes:"
log "  1. Runtipi s'installera automatiquement au premier démarrage"
log "  2. Docker sera installé par Runtipi"
log "  3. Connectez-vous via WiFi 'RuntipiOS-Setup'"
log ""
log "======================================"

