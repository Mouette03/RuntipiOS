#!/bin/bash
# RuntipiOS Image Builder - Version Finale Robuste
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
LOOP_DEVICE=""

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
    if [ -n "${LOOP_DEVICE}" ]; then losetup -d "${LOOP_DEVICE}" 2>/dev/null || true; fi
}
trap cleanup EXIT

# --- Lecture de la configuration ---
log_info "Lecture sécurisée de la configuration depuis ${CONFIG_FILE}..."
if [ ! -f "$CONFIG_FILE" ]; then log_error "Fichier de configuration introuvable!" && exit 1; fi

get_config() { yq -r "$1" "$CONFIG_FILE"; }

RASPIOS_URL=$(get_config '.raspios.url')
RASPIOS_ARCH=$(get_config '.raspios.arch')
BUILD_IMAGE_SIZE=$(get_config '.build.image_size')
BUILD_COMPRESS=$(get_config '.build.compress')
BUILD_COMPRESSION_FORMAT=$(get_config '.build.compression_format')

if [ -z "$RASPIOS_URL" ]; then log_error "raspios.url n'est pas défini dans config.yml" && exit 1; fi
log_success "Configuration lue avec succès."

# --- Préparation de l'image ---
BASE_IMAGE_XZ="${WORK_DIR}/raspios-base.img.xz"
BASE_IMAGE="${WORK_DIR}/raspios-base.img"

log_info "Création des répertoires de travail..."
mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"

log_info "Téléchargement de Raspberry Pi OS depuis ${RASPIOS_URL}..."
if [ ! -f "$BASE_IMAGE" ]; then
    wget -O "$BASE_IMAGE_XZ" "$RASPIOS_URL"
    log_info "Extraction de l'image..."
    xz -d -k "$BASE_IMAGE_XZ"
fi

log_info "Agrandissement de l'image à ${BUILD_IMAGE_SIZE}G..."
truncate -s "${BUILD_IMAGE_SIZE}G" "$BASE_IMAGE"

# --- Montage et Chroot ---
log_info "Montage de l'image..."
parted -s "$BASE_IMAGE" resizepart 2 100%

# --- MODIFICATION DÉFINITIVE ICI ---
# Ajout du drapeau -P pour forcer le scan des partitions
LOOP_DEVICE=$(losetup -f --show -P "$BASE_IMAGE")

BOOT_PART="${LOOP_DEVICE}p1"
ROOT_PART="${LOOP_DEVICE}p2"

sleep 2 # Laisser le temps aux partitions d'apparaître

mount "$ROOT_PART" "$MOUNT_DIR"
mkdir -p "${MOUNT_DIR}/boot/firmware"
mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"

log_info "Préparation de l'environnement chroot..."
cp /etc/resolv.conf "${MOUNT_DIR}/etc/"
if [ "$(uname -m)" != "$RASPIOS_ARCH" ]; then
    cp "/usr/bin/qemu-$(uname -m)-static" "${MOUNT_DIR}/usr/bin/" 2>/dev/null || cp "/usr/bin/qemu-aarch64-static" "${MOUNT_DIR}/usr/bin/"
fi

# --- Exécution des scripts de personnalisation ---
log_info "Copie des scripts et de la config dans l'image..."
cp -r /build/scripts "${MOUNT_DIR}/tmp/"
cp "$CONFIG_FILE" "${MOUNT_DIR}/tmp/config.yml"

log_info "Exécution de la personnalisation dans l'environnement chroot..."
mount -t proc proc "${MOUNT_DIR}/proc"
mount -t sysfs sys "${MOUNT_DIR}/sys"
mount -o bind /dev "${MOUNT_DIR}/dev"

if ! chroot "$MOUNT_DIR" /bin/bash -c "/tmp/scripts/customize-os.sh"; then log_error "customize-os.sh a échoué!" && exit 1; fi
if ! chroot "$MOUNT_DIR" /bin/bash -c "/tmp/scripts/install-wifi-connect.sh"; then log_error "install-wifi-connect.sh a échoué!" && exit 1; fi
if ! chroot "$MOUNT_DIR" /bin/bash -c "/tmp/scripts/setup-services.sh"; then log_error "setup-services.sh a échoué!" && exit 1; fi

# --- Nettoyage et Finalisation ---
log_info "Nettoyage final de l'image..."
rm -rf "${MOUNT_DIR}/tmp/scripts" "${MOUNT_DIR}/tmp/config.yml"
chroot "$MOUNT_DIR" apt-get clean

cleanup
trap - EXIT

log_info "Copie de l'image finale..."
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
