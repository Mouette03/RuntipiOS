#!/bin/bash
# RuntipiOS Image Builder - Version Finale avec kpartx
set -euo pipefail

# --- Fonctions de log ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Définitions initiales ---
BUILD_DIR="/build"
CONFIG_FILE="${BUILD_DIR}/config.yml"
WORK_DIR="${BUILD_DIR}/work"
MOUNT_DIR="${BUILD_DIR}/mount"
OUTPUT_DIR="${BUILD_DIR}/output"
LOOP_DEVICE_PATH=""

# --- Nettoyage ---
cleanup() {
    set +e
    log_info "Nettoyage en cours..."
    sync
    umount -l "${MOUNT_DIR}/dev/pts" 2>/dev/null || true
    umount -l "${MOUNT_DIR}/dev" 2>/dev/null || true
    umount -l "${MOUNT_DIR}/sys" 2>/dev/null || true
    umount -l "${MOUNT_DIR}/proc" 2>/dev/null || true
    umount -l "${MOUNT_DIR}/boot/firmware" 2>/dev/null || true
    umount -l "${MOUNT_DIR}" 2>/dev/null || true
    
    # Utilisation de kpartx pour le nettoyage
    if [ -f "${WORK_DIR}/raspios-base.img" ]; then
        kpartx -d "${WORK_DIR}/raspios-base.img" 2>/dev/null || true
    fi
    
    # Détachement du loop device principal
    if [ -n "${LOOP_DEVICE_PATH}" ]; then
        losetup -d "${LOOP_DEVICE_PATH}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# --- Lecture de la configuration ---
log_info "Lecture de la configuration depuis ${CONFIG_FILE}..."
if [ ! -f "$CONFIG_FILE" ]; then log_error "Fichier de configuration introuvable!" && exit 1; fi
get_config() { yq -r "$1" "$CONFIG_FILE"; }

RASPIOS_URL=$(get_config '.raspios.url')
RASPIOS_ARCH=$(get_config '.raspios.arch')
BUILD_IMAGE_SIZE=$(get_config '.build.image_size')
BUILD_COMPRESS=$(get_config '.build.compress')
BUILD_COMPRESSION_FORMAT=$(get_config '.build.compression_format')

if [ -z "$RASPIOS_URL" ]; then log_error "raspios.url n'est pas défini dans config.yml" && exit 1; fi

# --- Préparation de l'image ---
BASE_IMAGE_XZ="${WORK_DIR}/raspios-base.img.xz"
BASE_IMAGE="${WORK_DIR}/raspios-base.img"

mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"

if [ ! -f "$BASE_IMAGE" ]; then
    log_info "Téléchargement de Raspberry Pi OS..."
    wget -O "$BASE_IMAGE_XZ" "$RASPIOS_URL"
    log_info "Extraction de l'image..."
    xz -d -k "$BASE_IMAGE_XZ"
fi

log_info "Agrandissement de l'image à ${BUILD_IMAGE_SIZE}G..."
truncate -s "${BUILD_IMAGE_SIZE}G" "$BASE_IMAGE"
parted -s "$BASE_IMAGE" resizepart 2 100%

# ============================================================================
#               --- MONTAGE ROBUSTE AVEC KPARTX ---
# ============================================================================
log_info "Mappage des partitions avec kpartx..."
# La commande kpartx crée les mappings dans /dev/mapper/
MAPS=$(kpartx -avs "$BASE_IMAGE" | awk '{print $3}')
LOOP_DEVICE_NAME=$(echo "$MAPS" | head -n1 | sed 's/p[0-9]*$//')
BOOT_PART="/dev/mapper/$(echo "$MAPS" | grep 'p1' || echo "${LOOP_DEVICE_NAME}1")"
ROOT_PART="/dev/mapper/$(echo "$MAPS" | grep 'p2' || echo "${LOOP_DEVICE_NAME}2")"
LOOP_DEVICE_PATH="/dev/$(losetup -j "$BASE_IMAGE" | cut -d: -f1 | xargs basename)"

sleep 2 # Laisser le temps aux mappings de se stabiliser

log_info "Montage de ${ROOT_PART} sur ${MOUNT_DIR}"
mount "$ROOT_PART" "$MOUNT_DIR"
mkdir -p "${MOUNT_DIR}/boot/firmware"
log_info "Montage de ${BOOT_PART} sur ${MOUNT_DIR}/boot/firmware"
mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"
log_success "Partitions montées avec succès !"
# ============================================================================

# --- Préparation et exécution du chroot ---
cp /etc/resolv.conf "${MOUNT_DIR}/etc/"
if [ "$(uname -m)" != "$RASPIOS_ARCH" ]; then
    cp "/usr/bin/qemu-aarch64-static" "${MOUNT_DIR}/usr/bin/"
fi

cp -r /build/scripts "${MOUNT_DIR}/tmp/"
cp "$CONFIG_FILE" "${MOUNT_DIR}/tmp/config.yml"

mount -t proc proc "${MOUNT_DIR}/proc"
mount -t sysfs sys "${MOUNT_DIR}/sys"
mount -o bind /dev "${MOUNT_DIR}/dev"

log_info "Exécution des scripts de personnalisation en chroot..."
chroot "$MOUNT_DIR" /bin/bash -c "/tmp/scripts/customize-os.sh"
chroot "$MOUNT_DIR" /bin/bash -c "/tmp/scripts/install-wifi-connect.sh"
chroot "$MOUNT_DIR" /bin/bash -c "/tmp/scripts/setup-services.sh"

# --- Nettoyage et Finalisation ---
rm -rf "${MOUNT_DIR}/tmp/scripts" "${MOUNT_DIR}/tmp/config.yml"
chroot "$MOUNT_DIR" apt-get clean
cleanup
trap - EXIT

FINAL_IMAGE="${OUTPUT_DIR}/${OUTPUT_NAME}.img"
mv "$BASE_IMAGE" "$FINAL_IMAGE"

if [ "$BUILD_COMPRESS" = "true" ]; then
    log_info "Compression de l'image en .${BUILD_COMPRESSION_FORMAT}..."
    case "$BUILD_COMPRESSION_FORMAT" in
        xz) xz -T0 "$FINAL_IMAGE" ;;
        gz) gzip "$FINAL_IMAGE" ;;
        zip) zip -j "${FINAL_IMAGE}.zip" "$FINAL_IMAGE" && rm "$FINAL_IMAGE" ;;
    esac
fi

log_success "Build de RuntipiOS terminé avec succès !"
