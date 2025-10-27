#!/bin/bash
set -euo pipefail

# RuntipiOS Image Builder - Version complète et corrigée
# Pour GitHub Actions (x86-64 avec kpartx fallback)

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

# Agrandir l'image
log_info "Agrandissement de l'image à ${CONFIG_build_image_size}GB..."
CURRENT_SIZE=$(stat -L -c%s "$BASE_IMAGE")
TARGET_SIZE=$((CONFIG_build_image_size * 1024 * 1024 * 1024))

if [ $TARGET_SIZE -gt $CURRENT_SIZE ]; then
    truncate -s ${TARGET_SIZE} "$BASE_IMAGE"
    
    # Redimensionner la partition
    echo ", +" | sfdisk -N 2 "$BASE_IMAGE" 2>/dev/null || true
    log_success "Image agrandie"
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
    
    # Extraire SEULEMENT les lignes "add map" pour éviter les faux positifs
    BOOT_MAPPER=$(echo "$KPARTX_OUTPUT" | grep "^add map" | grep "p1" | awk '{print $3}')
    ROOT_MAPPER=$(echo "$KPARTX_OUTPUT" | grep "^add map" | grep "p2" | awk '{print $3}')
    
    BOOT_PART="/dev/mapper/${BOOT_MAPPER}"
    ROOT_PART="/dev/mapper/${ROOT_MAPPER}"
    USE_KPARTX=1
    
    log_info "Devices kpartx créés:"
    log_info "  Boot mapper: ${BOOT_MAPPER}"
    log_info "  Root mapper: ${ROOT_MAPPER}"
fi

log_info "Boot partition: $BOOT_PART"
log_info "Root partition: $ROOT_PART"

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

# Redimensionner le système de fichiers root
log_info "Redimensionnement du système de fichiers..."
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

# Monter les pseudo-filesystems pour chroot
log_info "Préparation du chroot..."
mount -t proc proc "${MOUNT_DIR}/proc"
mount -t sysfs sys "${MOUNT_DIR}/sys"
mount -o bind /dev "${MOUNT_DIR}/dev"
mount -t devpts devpts "${MOUNT_DIR}/dev/pts"

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

# Copier et compresser l'image finale
log_info "Préparation de l'image finale..."
OUTPUT_NAME="${OUTPUT_NAME:-RuntipiOS-$(date +%Y%m%d)}-${CONFIG_raspios_arch}"
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

# Afficher les informations finales
log_success "======================================"
log_success "Build terminé avec succès !"
log_success "======================================"
echo ""
echo "Image finale: $(basename $FINAL_IMAGE)"
echo "Taille: $(du -h $FINAL_IMAGE | cut -f1)"
echo "Emplacement: $FINAL_IMAGE"
echo ""
echo "Pour flasher l'image sur une carte SD:"
echo "  - Utilisez Raspberry Pi Imager: https://www.raspberrypi.com/software/"
echo "  - Ou Etcher: https://www.balena.io/etcher/"
echo ""
log_info "N'oubliez pas de changer le mot de passe par défaut après le premier démarrage !"