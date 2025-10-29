#!/bin/bash
# Script de redimensionnement du filesystem root pour Pi 5
# À exécuter au premier boot
# Créé par: RuntipiOS Builder


set -e


log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/expand-rootfs.log
}


log "======================================"
log "Redimensionnement du filesystem root"
log "======================================"


# Vérifier si déjà exécuté
if [ -f /etc/expand-rootfs-done ]; then
    log "Redimensionnement déjà effectué, abandon"
    exit 0
fi


# Attendre que le système soit prêt
sleep 5


# Trouver la partition root
ROOT_PART=$(mount | grep -E "/ type " | awk '{print $1}' | head -1)
log "Partition root détectée: $ROOT_PART"


if [ -z "$ROOT_PART" ]; then
    log "❌ ERREUR: partition root introuvable"
    exit 1
fi


# Extraire le device (ex: /dev/mmcblk0 de /dev/mmcblk0p2)
DEVICE=$(echo $ROOT_PART | sed 's/[0-9]*$//')
PART_NUM=$(echo $ROOT_PART | sed 's/[^0-9]*//g' | tail -c 2)

log "Device: $DEVICE"
log "Partition: $PART_NUM"


# ============================================================================
# Redimensionner la table de partition
# ============================================================================
log "Redimensionnement de la table de partition..."


if command -v parted &> /dev/null; then
    log "Utilisation de parted (recommandé pour Pi 5)..."
    parted -s "$DEVICE" resizepart "$PART_NUM" 100% 2>&1 | tee -a /var/log/expand-rootfs.log || {
        log "⚠️  parted resizepart failed, essai alternatif..."
    }
else
    log "parted non disponible, utilisation de fdisk..."
    # Alternative avec fdisk (moins fiable sur Pi 5)
    log "⚠️  fdisk mode: cette méthode est moins stable, préférez parted"
fi


# Attendre que les changements de partition soient appliqués
sleep 3


# ============================================================================
# Redimensionner le filesystem ext4
# ============================================================================
log "Redimensionnement du filesystem ext4 sur $ROOT_PART..."


# Vérifier le filesystem
e2fsck -f -y "$ROOT_PART" 2>&1 | tee -a /var/log/expand-rootfs.log || true


# Attendre un peu
sleep 2


# Redimensionner
resize2fs "$ROOT_PART" 2>&1 | tee -a /var/log/expand-rootfs.log


# Vérifier le résultat
log "Vérification de l'espace disque..."
df -h / | tee -a /var/log/expand-rootfs.log


log "✅ Redimensionnement du filesystem terminé"


# Marquer comme exécuté
touch /etc/expand-rootfs-done
log "Fichier de marquage créé: /etc/expand-rootfs-done"


log "======================================"
log "Redémarrage pour appliquer les changements..."
log "======================================"


# Redémarrer
sleep 2
reboot
