#!/bin/bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info(){ echo -e "${BLUE}[INFO]${NC} $1"; }
log_success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning(){ echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1"; }

BUILD_DIR="/build"
WORK_DIR="${BUILD_DIR}/work"
MOUNT_DIR="${BUILD_DIR}/mount"
OUTPUT_DIR="${BUILD_DIR}/output"
CONFIG_FILE="${BUILD_DIR}/config.yml"

LOOP_DEVICE=""
USE_KPARTX=0
BOOT_PART=""
ROOT_PART=""

cleanup() {
  set +e
  log_info "Nettoyage..."
  sync
  umount "${MOUNT_DIR}/dev/pts" 2>/dev/null || true
  umount "${MOUNT_DIR}/dev" 2>/dev/null || true
  umount "${MOUNT_DIR}/sys" 2>/dev/null || true
  umount "${MOUNT_DIR}/proc" 2>/dev/null || true
  umount "${MOUNT_DIR}/boot/firmware" 2>/dev/null || true
  umount "${MOUNT_DIR}" 2>/dev/null || true
  
  if [ "${USE_KPARTX}" = "1" ]; then
    kpartx -d "${LOOP_DEVICE}" 2>/dev/null || true
  fi
  
  if [ -n "${LOOP_DEVICE}" ]; then
    losetup -d "${LOOP_DEVICE}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

parse_yaml() {
  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs
  fs=$(echo @|tr @ '\034')
  sed -ne "s|^\($s\):|\1|p" \
      -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s:$s\(.*\)$s$|\1$fs\2$fs\3|p" "$1" |
  awk -F"$fs" '{
    indent = length($1)/2;
    vname[indent]=$2;
    for (i in vname) { if (i>indent) { delete vname[i] } }
    if (length($3) > 0) {
      vn="";
      for (i=0; i<indent; i++) { vn=(vn)(vname[i])("_") }
      printf("CONFIG_%s%s=\"%s\"\n", vn, $2, $3);
    }
  }'
}

log_info "Chargement de la configuration..."
[ -f "$CONFIG_FILE" ] || { log_error "config.yml introuvable"; exit 1; }
eval "$(parse_yaml "$CONFIG_FILE")"

log_info "Configuration chargée"
mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"

log_info "Téléchargement de Raspberry Pi OS..."
BASE_IMAGE_XZ="${WORK_DIR}/raspios-base.img.xz"
BASE_IMAGE="${WORK_DIR}/raspios-base.img"

if [ ! -f "$BASE_IMAGE" ]; then
  [ -f "$BASE_IMAGE_XZ" ] || wget -O "$BASE_IMAGE_XZ" "$CONFIG_raspios_url" --max-redirect=10
  xz -d -k "$BASE_IMAGE_XZ"
fi
log_success "Image prête"

log_info "Agrandissement à ${CONFIG_build_image_size}GB..."
TARGET_SIZE=$(( CONFIG_build_image_size * 1024 * 1024 * 1024 ))
truncate -s "${TARGET_SIZE}" "$BASE_IMAGE"
echo ", +" | sfdisk -N 2 "$BASE_IMAGE" 2>/dev/null || true

log_info "Montage de l'image..."
LOOP_DEVICE=$(losetup -f --show -P "$BASE_IMAGE")
log_info "Loop device: $LOOP_DEVICE"
sleep 2

# Vérifier partitions directes
if [ -e "${LOOP_DEVICE}p1" ] && [ -e "${LOOP_DEVICE}p2" ]; then
  log_info "Partitions détectées directement"
  BOOT_PART="${LOOP_DEVICE}p1"
  ROOT_PART="${LOOP_DEVICE}p2"
  USE_KPARTX=0
else
  log_warning "Utilisation de kpartx..."
  
  # Utiliser kpartx et capturer la sortie
  KPARTX_OUTPUT=$(kpartx -av "$BASE_IMAGE")
  log_info "kpartx output: $KPARTX_OUTPUT"
  sleep 3
  
  # Extraire les vrais noms
  BOOT_MAPPER=$(echo "$KPARTX_OUTPUT" | grep "p1" | awk '{print $3}')
  ROOT_MAPPER=$(echo "$KPARTX_OUTPUT" | grep "p2" | awk '{print $3}')
  
  BOOT_PART="/dev/mapper/${BOOT_MAPPER}"
  ROOT_PART="/dev/mapper/${ROOT_MAPPER}"
  USE_KPARTX=1
fi

log_info "Boot partition: $BOOT_PART"
log_info "Root partition: $ROOT_PART"

# Vérifier existence
[ -e "$BOOT_PART" ] || { log_error "Boot introuvable"; ls -la /dev/mapper/; exit 1; }
[ -e "$ROOT_PART" ] || { log_error "Root introuvable"; ls -la /dev/mapper/; exit 1; }

log_info "Redimensionnement..."
e2fsck -f -y "$ROOT_PART" || true
resize2fs "$ROOT_PART"

log_info "Montage des partitions..."
mount "$ROOT_PART" "$MOUNT_DIR"
mkdir -p "${MOUNT_DIR}/boot/firmware"
mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"

log_info "Copie des scripts..."
cp "${BUILD_DIR}/scripts"/*.sh "${MOUNT_DIR}/tmp/" 2>/dev/null || true
cp "${CONFIG_FILE}" "${MOUNT_DIR}/tmp/"
chmod +x "${MOUNT_DIR}/tmp/"*.sh

log_info "Préparation chroot..."
cp /etc/resolv.conf "${MOUNT_DIR}/etc/"
mount -t proc proc "${MOUNT_DIR}/proc"
mount -t sysfs sys "${MOUNT_DIR}/sys"
mount -o bind /dev "${MOUNT_DIR}/dev"
mount -t devpts devpts "${MOUNT_DIR}/dev/pts"

log_info "Customisation du système..."
chroot "${MOUNT_DIR}" /bin/bash -c "/tmp/customize-os.sh" || true

log_info "Installation WiFi-Connect..."
chroot "${MOUNT_DIR}" /bin/bash -c "/tmp/install-wifi-connect.sh" || true

log_info "Configuration des services..."
chroot "${MOUNT_DIR}" /bin/bash -c "/tmp/setup-services.sh" || true

log_info "Nettoyage du chroot..."
rm -rf "${MOUNT_DIR}/tmp/"*.sh "${MOUNT_DIR}/tmp/config.yml"
chroot "${MOUNT_DIR}" apt-get clean 2>/dev/null || true

OUTPUT_NAME="${OUTPUT_NAME:-RuntipiOS-$(date +%Y%m%d)}-${CONFIG_raspios_arch}"
FINAL_IMAGE="${OUTPUT_DIR}/${OUTPUT_NAME}.img"

log_info "Copie de l'image finale..."
cp "$BASE_IMAGE" "$FINAL_IMAGE"

if [ "${CONFIG_build_compress}" = "true" ]; then
  log_info "Compression..."
  case "${CONFIG_build_compression_format}" in
    xz) xz -9 -T0 "$FINAL_IMAGE"; FINAL_IMAGE="${FINAL_IMAGE}.xz" ;;
    gz) gzip -9 "$FINAL_IMAGE"; FINAL_IMAGE="${FINAL_IMAGE}.gz" ;;
    zip) zip -9 "${FINAL_IMAGE}.zip" "$FINAL_IMAGE"; rm "$FINAL_IMAGE"; FINAL_IMAGE="${FINAL_IMAGE}.zip" ;;
  esac
fi

log_success "Build terminé!"
echo "Image: $(basename "$FINAL_IMAGE")"
echo "Taille: $(du -h "$FINAL_IMAGE" | cut -f1)"
