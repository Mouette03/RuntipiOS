#!/bin/bash
# RuntipiOS Image Builder - Version Robuste et Traçable
set -euo pipefail

# --- Fonctions de log, variables et nettoyage ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

BUILD_DIR="/build"
WORK_DIR="${BUILD_DIR}/work"
MOUNT_DIR="${BUILD_DIR}/mount"
OUTPUT_DIR="${BUILD_DIR}/output"
CONFIG_FILE="${BUILD_DIR}/config.yml"
LOOP_DEVICE=""
USE_KPARTX=0
BASE_IMAGE=""

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
    if [ "${USE_KPARTX}" = "1" ] && [ -n "${BASE_IMAGE}" ]; then kpartx -d "${BASE_IMAGE}" 2>/dev/null || true; fi
    if [ -n "${LOOP_DEVICE}" ]; then losetup -d "${LOOP_DEVICE}" 2>/dev/null || true; fi
}
trap cleanup EXIT

# --- Chargement de la config & Préparation de l'image ---
log_info "Chargement de la configuration depuis config.yml..."
eval "$(yq -o=shell "$CONFIG_FILE")"
BASE_IMAGE_XZ="${WORK_DIR}/raspios-base.img.xz"
BASE_IMAGE="${WORK_DIR}/raspios-base.img"

log_info "Création des répertoires de travail..."
mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"

log_info "Téléchargement de Raspberry Pi OS..."
if [ ! -f "$BASE_IMAGE" ]; then
    wget -O "$BASE_IMAGE_XZ" "$raspios_url"
    log_info "Extraction de l'image..."
    xz -d -k "$BASE_IMAGE_XZ"
fi

log_info "Agrandissement de l'image à ${build_image_size}GB..."
truncate -s "${build_image_size}G" "$BASE_IMAGE"

# --- Montage de l'image ---
log_info "Montage de l'image..."
LOOP_DEVICE=$(losetup -f --show -P "$BASE_IMAGE")
BOOT_PART="${LOOP_DEVICE}p1"
ROOT_PART="${LOOP_DEVICE}p2"
sleep 2 # Laisser le temps aux partitions d'apparaître
mount "$ROOT_PART" "$MOUNT_DIR"
mkdir -p "${MOUNT_DIR}/boot/firmware"
mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"

# --- Préparation du chroot ---
log_info "Préparation de l'environnement chroot..."
cp /etc/resolv.conf "${MOUNT_DIR}/etc/"
if [ "$(uname -m)" != "$raspios_arch" ]; then
    cp /usr/bin/qemu-aarch64-static "${MOUNT_DIR}/usr/bin/"
fi

# Création du service de redimensionnement au premier boot
log_info "Création du service de redimensionnement au premier boot..."
cat > "${MOUNT_DIR}/etc/systemd/system/expand-rootfs.service" << 'SERVICEEOF'
[Unit]
Description=Expand Root Filesystem on First Boot
ConditionPathExists=!/etc/expand-rootfs-done
[Service]
Type=oneshot
ExecStart=/bin/bash -c "parted /dev/mmcblk0 resizepart 2 100% && resize2fs /dev/mmcblk0p2 && touch /etc/expand-rootfs-done"
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
SERVICEEOF

# --- Exécution des scripts de personnalisation ---
log_info "Copie des scripts dans l'image..."
cp -r /build/scripts "${MOUNT_DIR}/tmp/"
cp "$CONFIG_FILE" "${MOUNT_DIR}/tmp/config.yml"

log_info "Exécution de la personnalisation dans l'environnement chroot..."
mount -t proc proc "${MOUNT_DIR}/proc"
mount -t sysfs sys "${MOUNT_DIR}/sys"
mount -o bind /dev "${MOUNT_DIR}/dev"

chroot "$MOUNT_DIR" systemctl enable expand-rootfs.service

if ! chroot "$MOUNT_DIR" /bin/bash -c "/tmp/scripts/customize-os.sh"; then
    log_error "customize-os.sh a échoué!" && exit 1; fi
if ! chroot "$MOUNT_DIR" /bin/bash -c "/tmp/scripts/install-wifi-connect.sh"; then
    log_error "install-wifi-connect.sh a échoué!" && exit 1; fi
if ! chroot "$MOUNT_DIR" /bin/bash -c "/tmp/scripts/setup-services.sh"; then
    log_error "setup-services.sh a échoué!" && exit 1; fi

# --- Nettoyage final de l'image ---
log_info "Nettoyage final de l'image..."
rm -rf "${MOUNT_DIR}/tmp/scripts" "${MOUNT_DIR}/tmp/config.yml"
chroot "$MOUNT_DIR" apt-get clean

# --- Démontage et finalisation ---
cleanup # La fonction de trap s'occupe du démontage
trap - EXIT

log_info "Copie de l'image finale..."
FINAL_IMAGE="${OUTPUT_DIR}/${OUTPUT_NAME}.img"
mv "$BASE_IMAGE" "$FINAL_IMAGE"

if [ "$build_compress" = "true" ]; then
    log_info "Compression de l'image en .${build_compression_format}..."
    case "$build_compression_format" in
        xz) xz -T0 "$FINAL_IMAGE" ;;
        gz) gzip "$FINAL_IMAGE" ;;
        zip) zip "${FINAL_IMAGE}.zip" "$FINAL_IMAGE" && rm "$FINAL_IMAGE" ;;
    esac
fi

log_success "Build de RuntipiOS terminé avec succès !"
