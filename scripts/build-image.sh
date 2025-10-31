#!/bin/bash
# RuntipiOS Image Builder - Version Finale Absolue
set -euo pipefail

# --- Fonctions de log ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Définitions & Nettoyage ---
BUILD_DIR="/build"; CONFIG_FILE="${BUILD_DIR}/config.yml"; WORK_DIR="${BUILD_DIR}/work"; MOUNT_DIR="${BUILD_DIR}/mount"; OUTPUT_DIR="${BUILD_DIR}/output"; LOOP_DEVICE_PATH=""
cleanup() { set +e; sync; umount -l "${MOUNT_DIR}/dev/pts" 2>/dev/null; umount -l "${MOUNT_DIR}/dev" 2>/dev/null; umount -l "${MOUNT_DIR}/sys" 2>/dev/null; umount -l "${MOUNT_DIR}/proc" 2>/dev/null; umount -l "${MOUNT_DIR}/boot/firmware" 2>/dev/null; umount -l "${MOUNT_DIR}" 2>/dev/null; if [ -f "${WORK_DIR}/raspios-base.img" ]; then kpartx -d "${WORK_DIR}/raspios-base.img" 2>/dev/null; fi; if [ -n "${LOOP_DEVICE_PATH}" ]; then losetup -d "${LOOP_DEVICE_PATH}" 2>/dev/null; fi; }
trap cleanup EXIT

# --- Lecture de la configuration ---
log_info "Lecture de la configuration..."
get_config() { yq -r "$1" "$CONFIG_FILE"; }
RASPIOS_URL=$(get_config '.raspios.url'); RASPIOS_ARCH=$(get_config '.raspios.arch'); BUILD_IMAGE_SIZE=$(get_config '.build.image_size'); BUILD_COMPRESS=$(get_config '.build.compress'); BUILD_COMPRESSION_FORMAT=$(get_config '.build.compression_format');
HOSTNAME=$(get_config '.system.hostname'); TIMEZONE=$(get_config '.system.timezone'); LOCALE=$(get_config '.system.locale'); KBD_LAYOUT=$(get_config '.system.keyboard_layout'); WIFI_COUNTRY=$(get_config '.system.wifi_country'); DEFAULT_USER=$(get_config '.system.default_user'); DEFAULT_PASSWORD=$(get_config '.system.default_password'); AUTOLOGIN=$(get_config '.system.autologin');
WIFI_CONNECT_VERSION=$(get_config '.wifi_connect.version'); PORTAL_SSID=$(get_config '.wifi_connect.ssid');
PACKAGES_INSTALL=$(get_config '.packages.install | join(" ")'); PACKAGES_REMOVE=$(get_config '.packages.remove | join(" ")');

# --- Préparation & Montage de l'image ---
BASE_IMAGE="${WORK_DIR}/raspios-base.img"
mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"
if [ ! -f "$BASE_IMAGE" ]; then wget -O "${BASE_IMAGE}.xz" "$RASPIOS_URL" && xz -d -k "${BASE_IMAGE}.xz"; fi
truncate -s "${BUILD_IMAGE_SIZE}G" "$BASE_IMAGE"
parted -s "$BASE_IMAGE" resizepart 2 100%

MAPS=$(kpartx -avs "$BASE_IMAGE" | awk '{print $3}'); LOOP_DEVICE_NAME=$(echo "$MAPS" | head -n1 | sed 's/p[0-9]*$//'); BOOT_PART="/dev/mapper/$(echo "$MAPS" | grep 'p1')"; ROOT_PART="/dev/mapper/$(echo "$MAPS" | grep 'p2')"; LOOP_DEVICE_PATH="/dev/$(losetup -j "$BASE_IMAGE" | cut -d: -f1 | xargs basename)"; sleep 2
mount "$ROOT_PART" "$MOUNT_DIR"; mkdir -p "${MOUNT_DIR}/boot/firmware"; mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"

# --- Chroot ---
cp /etc/resolv.conf "${MOUNT_DIR}/etc/"; if [ "$(uname -m)" != "$RASPIOS_ARCH" ]; then cp "/usr/bin/qemu-aarch64-static" "${MOUNT_DIR}/usr/bin/"; fi
cp -r /build/scripts "${MOUNT_DIR}/tmp/"
mount -t proc proc "${MOUNT_DIR}/proc"; mount -t sysfs sys "${MOUNT_DIR}/sys"; mount -o bind /dev "${MOUNT_DIR}/dev"

log_info "Exécution de customize-os.sh en chroot..."
chroot "$MOUNT_DIR" /bin/bash "/tmp/scripts/customize-os.sh" "$HOSTNAME" "$TIMEZONE" "$LOCALE" "$KBD_LAYOUT" "$WIFI_COUNTRY" "$DEFAULT_USER" "$DEFAULT_PASSWORD" "$AUTOLOGIN" "$PACKAGES_INSTALL" "$PACKAGES_REMOVE"

log_info "Exécution de install-wifi-connect.sh en chroot..."
chroot "$MOUNT_DIR" /bin/bash "/tmp/scripts/install-wifi-connect.sh" "$WIFI_CONNECT_VERSION" "$RASPIOS_ARCH" "$PORTAL_SSID"

log_info "Exécution de setup-services.sh en chroot..."
chroot "$MOUNT_DIR" /bin/bash "/tmp/scripts/setup-services.sh"

# --- Activation manuelle des services ---
log_info "Activation manuelle des services pour l'environnement chroot..."
for service in expand-rootfs.service unblock-rfkill.service runtipios-first-boot.service avahi-daemon.service; do
    ln -sf "/etc/systemd/system/${service}" "${MOUNT_DIR}/etc/systemd/system/multi-user.target.wants/${service}"
done
if echo "$PACKAGES_INSTALL" | grep -q "unattended-upgrades"; then
    chroot "$MOUNT_DIR" dpkg-reconfigure -plow unattended-upgrades
fi

# --- Finalisation ---
rm -rf "${MOUNT_DIR}/tmp/scripts"
chroot "$MOUNT_DIR" apt-get clean
cleanup; trap - EXIT

FINAL_IMAGE="${OUTPUT_DIR}/${OUTPUT_NAME}.img"
mv "$BASE_IMAGE" "$FINAL_IMAGE"
if [ "$BUILD_COMPRESS" = "true" ]; then
    case "$BUILD_COMPRESSION_FORMAT" in
        xz) xz -T0 "$FINAL_IMAGE" ;;
        gz) gzip "$FINAL_IMAGE" ;;
        zip) zip -j "${FINAL_IMAGE}.zip" "$FINAL_IMAGE" && rm "$FINAL_IMAGE" ;;
    esac
fi
log_success "Build terminé avec succès !"
