#!/bin/bash
set -euo pipefail

# RuntipiOS Image Builder - Version corrigée Pi 5
# Pour GitHub Actions (x86-64 avec support ARM64 via QEMU)

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Variables globales
BUILD_DIR="/build"
WORK_DIR="${BUILD_DIR}/work"
MOUNT_DIR="${BUILD_DIR}/mount"
OUTPUT_DIR="${BUILD_DIR}/output"
CONFIG_FILE="${BUILD_DIR}/config.yml"

LOOP_DEVICE=""
USE_KPARTX=0
BOOT_PART=""
ROOT_PART=""
BASE_IMAGE=""

# Fonction de nettoyage
cleanup() {
    set +e
    log_info "Nettoyage en cours..."
    sync
    
    # Démonter les pseudo-filesystems du chroot
    umount "${MOUNT_DIR}/dev/pts" 2>/dev/null || true
    umount "${MOUNT_DIR}/dev" 2>/dev/null || true
    umount "${MOUNT_DIR}/sys" 2>/dev/null || true
    umount "${MOUNT_DIR}/proc" 2>/dev/null || true
    
    # Démonter les partitions
    umount "${MOUNT_DIR}/boot/firmware" 2>/dev/null || true
    umount "${MOUNT_DIR}" 2>/dev/null || true
    
    # Nettoyer kpartx si utilisé
    if [ "${USE_KPARTX}" = "1" ] && [ -n "${BASE_IMAGE}" ] && [ -f "${BASE_IMAGE}" ]; then
        kpartx -d "${BASE_IMAGE}" 2>/dev/null || true
    fi
    
    # Détacher le loop device
    if [ -n "${LOOP_DEVICE}" ]; then
        losetup -d "${LOOP_DEVICE}" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Parser YAML simple
parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs
    fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s$|\1$fs\2$fs\3|p" "$1" |
    awk -F"$fs" '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn="";
            for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }'
}

echo "======================================"
echo "RuntipiOS Image Builder"
echo "======================================"
echo ""

# Charger la configuration
log_info "Chargement de la configuration depuis config.yml..."
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Fichier config.yml introuvable !"
    exit 1
fi

eval $(parse_yaml "$CONFIG_FILE" "CONFIG_")

# Afficher la configuration
log_info "Configuration chargée :"
echo "  - Raspberry Pi OS: ${CONFIG_raspios_version} (${CONFIG_raspios_variant}, ${CONFIG_raspios_arch})"
echo "  - Runtipi: ${CONFIG_runtipi_version}"
echo "  - WiFi-Connect: ${CONFIG_wifi_connect_version}"
echo "  - Hostname: ${CONFIG_system_hostname}"
echo "  - Image size: ${CONFIG_build_image_size} GB"
echo ""

# ============================================================================
# ACTIVATION QEMU POUR SUPPORT ARM64
# ============================================================================
log_info "Vérification de l'architecture..."
CURRENT_ARCH=$(uname -m)
TARGET_ARCH="${CONFIG_raspios_arch}"

log_info "Architecture courante: $CURRENT_ARCH"
log_info "Architecture cible: $TARGET_ARCH"

# Si on est en x86-64 et cible ARM, activer QEMU
if [ "$CURRENT_ARCH" = "x86_64" ] && [ "$TARGET_ARCH" = "arm64" ]; then
    log_info "Activation de QEMU pour support ARM64..."
    
    # Enregistrer les formats binaires
    if command -v update-binfmts &> /dev/null; then
        update-binfmts --enable qemu-aarch64 2>/dev/null || log_warning "update-binfmts warning (non-critique)"
    fi
    
    # Vérifier que QEMU est disponible
    if ! command -v qemu-aarch64-static &> /dev/null; then
        log_error "qemu-aarch64-static non trouvé!"
        log_error "Vérifiez que le Dockerfile installe qemu-user-static"
        exit 1
    fi
    
    log_success "QEMU ARM64 activé"
fi

echo ""

# Créer les répertoires de travail
log_info "Création des répertoires de travail..."
mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"

# Télécharger l'image Raspberry Pi OS de base
log_info "Téléchargement de Raspberry Pi OS..."
BASE_IMAGE_XZ="${WORK_DIR}/raspios-base.img.xz"
BASE_IMAGE="${WORK_DIR}/raspios-base.img"

if [ ! -f "$BASE_IMAGE" ]; then
    if [ ! -f "$BASE_IMAGE_XZ" ]; then
        wget -O "$BASE_IMAGE_XZ" "$CONFIG_raspios_url" --max-redirect=10
        log_success "Image Raspberry Pi OS téléchargée"
    else
        log_warning "Archive déjà téléchargée, réutilisation"
    fi
    
    # Extraire l'image
    log_info "Extraction de l'image..."
    xz -d -k "$BASE_IMAGE_XZ"
    log_success "Image extraite"
else
    log_warning "Image déjà extraite, réutilisation"
fi

# ============================================================================
# AGRANDISSEMENT DE L'IMAGE - MÉTHODE COMPATIBLE PI 5
# ============================================================================
# Pi 5 ne supporte pas le redimensionnement avec sfdisk
# On augmente simplement la taille du fichier image
# Le redimensionnement du filesystem se fera au premier boot
# ============================================================================
log_info "Agrandissement de l'image à ${CONFIG_build_image_size}GB..."
CURRENT_SIZE=$(stat -L -c%s "$BASE_IMAGE")
TARGET_SIZE=$((CONFIG_build_image_size * 1024 * 1024 * 1024))

if [ $TARGET_SIZE -gt $CURRENT_SIZE ]; then
    truncate -s ${TARGET_SIZE} "$BASE_IMAGE"
    log_success "Image agrandie (le filesystem sera redimensionné au premier boot)"
fi

# Monter l'image
log_info "Montage de l'image..."
LOOP_DEVICE=$(losetup -f --show -P "$BASE_IMAGE")
log_info "Loop device: $LOOP_DEVICE"

# Attendre que les partitions soient disponibles
sleep 2

# Vérifier si les partitions directes existent
if [ -e "${LOOP_DEVICE}p1" ] && [ -e "${LOOP_DEVICE}p2" ]; then
    log_info "Partitions détectées directement"
    BOOT_PART="${LOOP_DEVICE}p1"
    ROOT_PART="${LOOP_DEVICE}p2"
    USE_KPARTX=0
else
    log_warning "Partitions non détectées, utilisation de kpartx..."
    
    # Utiliser kpartx et capturer la sortie
    KPARTX_OUTPUT=$(kpartx -av "$BASE_IMAGE")
    sleep 3
    
    # Utiliser awk avec exit pour n'extraire QUE la première ligne qui match
    BOOT_MAPPER=$(echo "$KPARTX_OUTPUT" | awk '/^add map.*p1 / {print $3; exit}')
    ROOT_MAPPER=$(echo "$KPARTX_OUTPUT" | awk '/^add map.*p2 / {print $3; exit}')
    
    # Vérifier que les variables ne sont pas vides
    if [ -z "$BOOT_MAPPER" ] || [ -z "$ROOT_MAPPER" ]; then
        log_error "Impossible d'extraire les noms des mappers depuis kpartx"
        log_info "Output kpartx complet:"
        echo "$KPARTX_OUTPUT"
        exit 1
    fi
    
    BOOT_PART="/dev/mapper/${BOOT_MAPPER}"
    ROOT_PART="/dev/mapper/${ROOT_MAPPER}"
    USE_KPARTX=1
    
    log_info "Devices kpartx créés:"
    log_info "  Boot: ${BOOT_MAPPER} -> ${BOOT_PART}"
    log_info "  Root: ${ROOT_MAPPER} -> ${ROOT_PART}"
fi

log_info "Vérification des partitions..."
log_info "  Boot partition: $BOOT_PART"
log_info "  Root partition: $ROOT_PART"

# Vérifier que les partitions existent
if [ ! -e "$BOOT_PART" ]; then
    log_error "Boot partition introuvable: $BOOT_PART"
    log_info "Contenu de /dev/mapper/:"
    ls -la /dev/mapper/ || true
    exit 1
fi

if [ ! -e "$ROOT_PART" ]; then
    log_error "Root partition introuvable: $ROOT_PART"
    log_info "Contenu de /dev/mapper/:"
    ls -la /dev/mapper/ || true
    exit 1
fi

log_success "Partitions trouvées et vérifiées"

# ============================================================================
# REDIMENSIONNER LE FILESYSTEM ROOT EXISTANT
# ============================================================================
log_info "Redimensionnement du système de fichiers root..."
e2fsck -f -y "$ROOT_PART" || true
resize2fs "$ROOT_PART"

# Monter les partitions
log_info "Montage des partitions..."
mount "$ROOT_PART" "$MOUNT_DIR"
mkdir -p "${MOUNT_DIR}/boot/firmware"
mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"

log_success "Image montée sur $MOUNT_DIR"

# Configurer le système
log_info "Configuration du système..."

# Copier les résolveurs DNS
cp /etc/resolv.conf "${MOUNT_DIR}/etc/resolv.conf"

# Copier QEMU si nécessaire pour le chroot
if [ "$CURRENT_ARCH" = "x86_64" ] && [ "$TARGET_ARCH" = "arm64" ]; then
    log_info "Copie de QEMU ARM64 dans le chroot..."
    mkdir -p "${MOUNT_DIR}/usr/bin"
    cp /usr/bin/qemu-aarch64-static "${MOUNT_DIR}/usr/bin/" 2>/dev/null || log_warning "QEMU copy failed"
fi

# ============================================================================
# CRÉER LE SCRIPT DE REDIMENSIONNEMENT POUR PI 5
# ============================================================================
log_info "Création du script de redimensionnement pour Pi 5..."
cat > "${MOUNT_DIR}/usr/local/bin/expand-rootfs.sh" << 'EXPANDEOF'
#!/bin/bash
# Script de redimensionnement du filesystem root pour Pi 5
# À exécuter au premier boot

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
log "Partition root: $ROOT_PART"

if [ -z "$ROOT_PART" ]; then
    log "Erreur: partition root introuvable"
    exit 1
fi

# Redimensionner la table de partition
log "Redimensionnement de la table de partition..."
DEVICE=$(echo $ROOT_PART | sed 's/[0-9]*$//')
PART_NUM=$(echo $ROOT_PART | sed 's/[^0-9]*//g' | tail -c 2)

# Utiliser parted au lieu de sfdisk (plus compatible Pi 5)
if command -v parted &> /dev/null; then
    parted -s "$DEVICE" resizepart "$PART_NUM" 100% || log "parted resizepart failed"
else
    log "parted non disponible, utilisation de fdisk"
    # Alternative avec fdisk
    echo "d
$PART_NUM
n
p
$PART_NUM


t
$PART_NUM
83
w
" | fdisk "$DEVICE" 2>&1 | grep -v "^WARNING"
fi

log "Redimensionnement du filesystem ext4..."
# Attendre que les changements soient appliqués
sleep 2

# Redimensionner le filesystem
resize2fs "$ROOT_PART"

log "✓ Redimensionnement terminé"
touch /etc/expand-rootfs-done

log "======================================"
log "Redémarrage pour appliquer les changements..."
sleep 2
reboot
EXPANDEOF

chmod +x "${MOUNT_DIR}/usr/local/bin/expand-rootfs.sh"
log_success "Script de redimensionnement créé"

# ============================================================================
# CRÉER LE SERVICE SYSTEMD POUR EXÉCUTER LE REDIMENSIONNEMENT
# ============================================================================
log_info "Création du service systemd pour redimensionnement..."
cat > "${MOUNT_DIR}/etc/systemd/system/expand-rootfs.service" << 'SERVICEEOF'
[Unit]
Description=Expand Root Filesystem
After=multi-user.target
ConditionPathExists=!/etc/expand-rootfs-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/expand-rootfs.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

log_success "Service systemd créé"

# Monter les pseudo-filesystems pour chroot
log_info "Préparation du chroot..."
mount -t proc proc "${MOUNT_DIR}/proc"
mount -t sysfs sys "${MOUNT_DIR}/sys"
mount -o bind /dev "${MOUNT_DIR}/dev"
mount -t devpts devpts "${MOUNT_DIR}/dev/pts"

# Activer le service dans le chroot
chroot "$MOUNT_DIR" systemctl enable expand-rootfs.service 2>/dev/null || log_warning "systemctl enable failed in chroot"

# Copier les scripts dans le chroot
log_info "Copie des scripts de configuration..."
cp "${BUILD_DIR}/scripts/customize-os.sh" "${MOUNT_DIR}/tmp/customize-os.sh"
cp "${BUILD_DIR}/scripts/install-wifi-connect.sh" "${MOUNT_DIR}/tmp/install-wifi-connect.sh"
cp "${BUILD_DIR}/scripts/install-runtipi.sh" "${MOUNT_DIR}/tmp/install-runtipi.sh"
cp "${BUILD_DIR}/scripts/setup-services.sh" "${MOUNT_DIR}/tmp/setup-services.sh"
cp "$CONFIG_FILE" "${MOUNT_DIR}/tmp/config.yml"
chmod +x "${MOUNT_DIR}/tmp/"*.sh

# Exécuter les scripts de configuration dans le chroot
log_info "Customisation du système d'exploitation..."
chroot "$MOUNT_DIR" /bin/bash -c "/tmp/customize-os.sh" || true

log_info "Installation de WiFi-Connect..."
chroot "$MOUNT_DIR" /bin/bash -c "/tmp/install-wifi-connect.sh" || true

log_info "Configuration des services systemd..."
chroot "$MOUNT_DIR" /bin/bash -c "/tmp/setup-services.sh" || true

log_success "Configuration système terminée"

# Nettoyer
log_info "Nettoyage du chroot..."
rm -f "${MOUNT_DIR}/tmp/"*.sh
rm -f "${MOUNT_DIR}/tmp/config.yml"
chroot "$MOUNT_DIR" apt-get clean 2>/dev/null || true
rm -rf "${MOUNT_DIR}/var/cache/apt/archives/"*.deb 2>/dev/null || true

# Démonter (sera aussi fait par trap cleanup)
log_info "Démontage de l'image..."
sync
umount "${MOUNT_DIR}/dev/pts" || true
umount "${MOUNT_DIR}/dev" || true
umount "${MOUNT_DIR}/sys" || true
umount "${MOUNT_DIR}/proc" || true
umount "${MOUNT_DIR}/boot/firmware"
umount "$MOUNT_DIR"

# Nettoyer kpartx si utilisé
if [ "${USE_KPARTX}" = "1" ]; then
    kpartx -d "$BASE_IMAGE" || true
fi

# Détacher loop
losetup -d "$LOOP_DEVICE"
LOOP_DEVICE=""

log_success "Image démontée"

# ============================================================================
# Copier et compresser l'image finale
# ============================================================================
log_info "Préparation de l'image finale..."

# Si OUTPUT_NAME n'est pas défini (passé par la ligne de commande), le créer
if [ -z "${OUTPUT_NAME:-}" ]; then
    OUTPUT_NAME="RuntipiOS-$(date +%Y%m%d)-${CONFIG_raspios_arch}"
fi

FINAL_IMAGE="${OUTPUT_DIR}/${OUTPUT_NAME}.img"

cp "$BASE_IMAGE" "$FINAL_IMAGE"
log_success "Image copiée vers $FINAL_IMAGE"

if [ "${CONFIG_build_compress}" = "true" ]; then
    log_info "Compression de l'image (cela peut prendre plusieurs minutes)..."
    
    case "${CONFIG_build_compression_format}" in
        xz)
            xz -9 -T0 "$FINAL_IMAGE"
            FINAL_IMAGE="${FINAL_IMAGE}.xz"
            ;;
        gz)
            gzip -9 "$FINAL_IMAGE"
            FINAL_IMAGE="${FINAL_IMAGE}.gz"
            ;;
        zip)
            zip -9 "${FINAL_IMAGE}.zip" "$FINAL_IMAGE"
            rm "$FINAL_IMAGE"
            FINAL_IMAGE="${FINAL_IMAGE}.zip"
            ;;
        *)
            log_warning "Format de compression inconnu: ${CONFIG_build_compression_format}"
            ;;
    esac
    
    log_success "Image compressée: $(basename $FINAL_IMAGE)"
fi

# ============================================================================
# NETTOYAGE DES FICHIERS TEMPORAIRES
# ============================================================================
log_info "Nettoyage des fichiers temporaires..."

# Supprimer les fichiers téléchargés/extraits de WORK_DIR
rm -f "${WORK_DIR}/raspios-base.img.xz"
rm -f "${WORK_DIR}/raspios-base.img"
log_info "Fichiers de téléchargement supprimés"

# Supprimer les formats de compression non utilisés
if [ "${CONFIG_build_compress}" = "true" ]; then
    case "${CONFIG_build_compression_format}" in
        xz)
            rm -f "${OUTPUT_DIR}/${OUTPUT_NAME}.img.gz" 2>/dev/null || true
            rm -f "${OUTPUT_DIR}/${OUTPUT_NAME}.img.zip" 2>/dev/null || true
            ;;
        gz)
            rm -f "${OUTPUT_DIR}/${OUTPUT_NAME}.img.xz" 2>/dev/null || true
            rm -f "${OUTPUT_DIR}/${OUTPUT_NAME}.img.zip" 2>/dev/null || true
            ;;
        zip)
            rm -f "${OUTPUT_DIR}/${OUTPUT_NAME}.img.xz" 2>/dev/null || true
            rm -f "${OUTPUT_DIR}/${OUTPUT_NAME}.img.gz" 2>/dev/null || true
            ;;
    esac
    
    # Supprimer l'image brute si elle existe (on a la version compressée)
    rm -f "${OUTPUT_DIR}/${OUTPUT_NAME}.img" 2>/dev/null || true
    log_info "Formats non utilisés supprimés"
fi

log_success "Nettoyage terminé"

# ============================================================================
# Afficher les informations finales
# ============================================================================
log_success "======================================"
log_success "Build terminé avec succès !"
log_success "======================================"
echo ""
echo "Image finale: $(basename $FINAL_IMAGE)"
echo "Taille: $(du -h $FINAL_IMAGE | cut -f1)"
echo "Emplacement: $FINAL_IMAGE"
echo ""
echo "Fichiers dans output/:"
ls -lh "${OUTPUT_DIR}/"
echo ""
echo "Pour flasher l'image sur une carte SD:"
echo "  - Utilisez Raspberry Pi Imager: https://www.raspberrypi.com/software/"
echo "  - Ou Etcher: https://www.balena.io/etcher/"
echo ""
log_info "Au premier démarrage, le filesystem sera automatiquement redimensionné (redémarrage automatique)"
