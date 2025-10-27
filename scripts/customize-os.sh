#!/bin/bash
# Script de customisation du système d'exploitation

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

# Installer les paquets nécessaires
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
    lsb-release

# Installer Docker
log "Installation de Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    log "✓ Docker installé"
else
    log "Docker déjà installé"
fi

# Installer Docker Compose
log "Installation de Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.24.5"
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Créer l'utilisateur
log "Création de l'utilisateur $DEFAULT_USER..."
if ! id "$DEFAULT_USER" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,docker "$DEFAULT_USER"
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
log "Configuration d'Avahi..."
systemctl enable avahi-daemon

# Nettoyer les paquets inutiles
log "Nettoyage..."
apt-get autoremove -y
apt-get clean

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

Documentation: https://github.com/votre-username/runtipios

EOF

# Créer la page de statut web
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
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
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
            font-family: 'Courier New', monospace;
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
        .loading {
            text-align: center;
            padding: 20px;
        }
        .spinner {
            border: 3px solid rgba(255, 255, 255, 0.3);
            border-top: 3px solid #fff;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .logo {
            text-align: center;
            margin-bottom: 20px;
            font-size: 4em;
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
                <span class="status-value" id="hostname">Loading...</span>
            </div>
            <div class="status-item">
                <span class="status-label">Adresse IP</span>
                <span class="status-value" id="ip">Loading...</span>
            </div>
            <div class="status-item">
                <span class="status-label">Runtipi</span>
                <span class="status-value" id="runtipi-status">En cours d'installation...</span>
            </div>
        </div>
        
        <div class="buttons">
            <a href="http://runtipios.local" class="button">Accéder à Runtipi</a>
            <a href="https://github.com/runtipi/runtipi" class="button" target="_blank">Documentation</a>
        </div>
    </div>
    
    <script>
        // Charger les informations du système
        async function loadStatus() {
            try {
                // Hostname
                document.getElementById('hostname').textContent = window.location.hostname;
                
                // IP
                const response = await fetch('/runtipi-info.json');
                if (response.ok) {
                    const data = await response.json();
                    document.getElementById('runtipi-status').textContent = 
                        data.status === 'running' ? '✓ Installé' : 'En cours...';
                }
            } catch (error) {
                console.error('Error loading status:', error);
            }
        }
        
        loadStatus();
        setInterval(loadStatus, 10000); // Rafraîchir toutes les 10s
    </script>
</body>
</html>
EOF

# Installer un serveur web léger pour la page de statut
apt-get install -y lighttpd
systemctl enable lighttpd

log "✓ Customisation terminée"
log "======================================"
