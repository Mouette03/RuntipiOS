#!/bin/bash
# Script d'installation de Runtipi (exécuté au premier démarrage)

set -e

LOG_FILE="/var/log/runtipi-install.log"
STATUS_FILE="/var/run/runtipi-install.status"

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "======================================"
log "Installation de Runtipi"
log "======================================"

# Charger la configuration
if [ -f /etc/runtipios/config.yml ]; then
    eval $(grep -E "^\s*version:" /etc/runtipios/config.yml | sed 's/^[[:space:]]*version:[[:space:]]*/RUNTIPI_VERSION=/' | sed 's/"//g')
    eval $(grep -E "^\s*repo_url:" /etc/runtipios/config.yml | sed 's/^[[:space:]]*repo_url:[[:space:]]*/RUNTIPI_REPO=/' | sed 's/"//g')
fi

RUNTIPI_VERSION=${RUNTIPI_VERSION:-"v3.8.0"}
RUNTIPI_REPO=${RUNTIPI_REPO:-"https://github.com/runtipi/runtipi.git"}
INSTALL_DIR="/home/runtipi/runtipi"

echo "downloading" > "$STATUS_FILE"

# Vérifier la connexion Internet
log "Vérification de la connexion Internet..."
for i in {1..30}; do
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        log "✓ Connexion Internet OK"
        break
    fi
    if [ $i -eq 30 ]; then
        log "✗ Pas de connexion Internet après 30 tentatives"
        echo "failed_no_internet" > "$STATUS_FILE"
        exit 1
    fi
    sleep 2
done

# Créer le répertoire d'installation
log "Création du répertoire d'installation..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "installing" > "$STATUS_FILE"

# Cloner Runtipi
log "Téléchargement de Runtipi ${RUNTIPI_VERSION}..."
if [ -d ".git" ]; then
    log "Mise à jour du dépôt existant..."
    git fetch --all --tags
    git checkout "$RUNTIPI_VERSION"
else
    log "Clonage du dépôt..."
    git clone "$RUNTIPI_REPO" .
    git checkout "$RUNTIPI_VERSION"
fi

log "✓ Runtipi téléchargé"

# Rendre le script d'installation exécutable
chmod +x ./scripts/install.sh

# Installer Runtipi
log "Installation de Runtipi (cela peut prendre 10-15 minutes)..."
echo "configuring" > "$STATUS_FILE"

# Exécuter l'installation en tant qu'utilisateur runtipi
chown -R runtipi:runtipi "$INSTALL_DIR"

# Lancer l'installation
su - runtipi -c "cd $INSTALL_DIR && sudo ./scripts/install.sh" 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log "✓ Runtipi installé avec succès !"
    echo "completed" > "$STATUS_FILE"
    
    # Obtenir l'adresse IP
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    HOSTNAME=$(hostname)
    
    log "======================================"
    log "Installation terminée !"
    log "======================================"
    log "Vous pouvez accéder à Runtipi via:"
    log "  - http://${HOSTNAME}.local"
    log "  - http://${IP_ADDRESS}"
    log "======================================"
    
    # Créer un fichier d'information pour la page de statut
    cat > /var/www/html/runtipi-info.json << EOF
{
    "status": "running",
    "version": "${RUNTIPI_VERSION}",
    "url": "http://${IP_ADDRESS}",
    "hostname_url": "http://${HOSTNAME}.local",
    "install_date": "$(date -Iseconds)"
}
EOF
    
    # Désactiver le service d'installation pour qu'il ne se relance pas
    systemctl disable runtipi-installer.service
    
else
    log "✗ Erreur lors de l'installation de Runtipi"
    echo "failed" > "$STATUS_FILE"
    exit 1
fi
