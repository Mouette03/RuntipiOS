#!/bin/bash
# build-image.sh — RuntipiOS Image Builder (complet et corrigé)

set -euo pipefail

# Couleurs log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info(){ echo -e "${BLUE}[INFO]${NC} $1"; }
log_success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning(){ echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1"; }

# Dossiers
BUILD_DIR="/build"
WORK_DIR="${BUILD_DIR}/work"
MOUNT_DIR="${BUILD_DIR}/mount"
OUTPUT_DIR="${BUILD_DIR}/output"
CONFIG_FILE="${BUILD_DIR}/config.yml"

# Variables globales de cleanup
LOOP_DEVICE=""
USE_KPARTX=0
BOOT_PART=""
ROOT_PART=""

cleanup() {
  set +e
  log_info "Nettoyage en cours..."
  sync
  # Unmount chroot mounts
  umount "${MOUNT_DIR}/dev/pts" 2>/dev/null || true
  umount "${MOUNT_DIR}/dev" 2>/dev/null || true
  umount "${MOUNT_DIR}/sys" 2>/dev/null || true
  umount "${MOUNT_DIR}/proc" 2>/dev/null || true
  umount "${MOUNT_DIR}/boot/firmware" 2>/dev/null || true
  umount "${MOUNT_DIR}" 2>/dev/null || true
  # Détacher mappings
  if [ "${USE_KPARTX}" = "1" ]; then
    if [ -n "${WORK_DIR:-}" ] && [ -f "${WORK_DIR}/raspios-base.img" ]; then
      kpartx -d "${WORK_DIR}/raspios-base.img" 2>/dev/null || true
    fi
  fi
  # Détacher loop
  if [ -n "${LOOP_DEVICE}" ]; then
    losetup -d "${LOOP_DEVICE}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Parser YAML très simple -> variables CONFIG_*
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

# Vérifs de base
log_info "Chargement de la configuration..."
if [ ! -f "$CONFIG_FILE" ]; then
  log_error "config.yml introuvable"
  exit 1
fi
eval "$(parse_yaml "$CONFIG_FILE")"

# Affichage config
log_info "Configuration:"
echo "  - Raspberry Pi OS URL: ${CONFIG_raspios_url}"
echo "  - Variant/Arch: ${CONFIG_raspios_variant}/${CONFIG_raspios_arch}"
echo "  - Hostname: ${CONFIG_system_hostname}"
echo "  - Image size: ${CONFIG_build_image_size} GB"

# Préparation répertoires
log_info "Création des répertoires de travail..."
mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"

# Téléchargement de l’image de base
log_info "Téléchargement de Raspberry Pi OS..."
BASE_IMAGE_XZ="${WORK_DIR}/raspios-base.img.xz"
BASE_IMAGE="${WORK_DIR}/raspios-base.img"

if [ ! -f "$BASE_IMAGE_XZ" ] && [ ! -f "$BASE_IMAGE" ]; then
  # Suivre redirections et nommer explicitement la sortie
  wget -O "$BASE_IMAGE_XZ" "$CONFIG_raspios_url" --max-redirect=10
  log_success "Image téléchargée: $(basename "$BASE_IMAGE_XZ")"
else
  log_warning "Image déjà présente, réutilisation"
fi

# Extraction xz
if [ ! -f "$BASE_IMAGE" ]; then
  log_info "Extraction de l'image (xz -d -k)..."
  xz -d -k "$BASE_IMAGE_XZ"
  log_success "Image extraite: $(basename "$BASE_IMAGE")"
fi

# Agrandissement de l’image
log_info "Agrandissement de l'image à ${CONFIG_build_image_size}GB..."
CURRENT_SIZE=$(stat -L -c%s "$BASE_IMAGE")
TARGET_SIZE=$(( CONFIG_build_image_size * 1024 * 1024 * 1024 ))
if [ "$TARGET_SIZE" -gt "$CURRENT_SIZE" ]; then
  truncate -s "${TARGET_SIZE}" "$BASE_IMAGE"
  # Étendre la partition 2 (root) jusqu'à la fin
  echo ", +" | sfdisk -N 2 "$BASE_IMAGE" 2>/dev/null || true
  log_success "Taille de l'image mise à jour"
fi

# Association loop + détection partitions
log_info "Montage de l'image via loop..."
LOOP_DEVICE=$(losetup -f --show -P "$BASE_IMAGE")
log_info "Loop device: $LOOP_DEVICE"

# Attendre détection partitions
for i in {1..10}; do
  if [ -e "${LOOP_DEVICE}p1" ] || [ -e "${LOOP_DEVICE}p2" ]; then
    break
  fi
  log_info "Attente des partitions... ($i/10)"
  partprobe "$LOOP_DEVICE" 2>/dev/null || true
  blockdev --rereadpt "$LOOP_DEVICE" 2>/dev/null || true
  sleep 1
done

# Fallback kpartx si pas de /dev/loopNp1
if [ ! -e "${LOOP_DEVICE}p1" ] || [ ! -e "${LOOP_DEVICE}p2" ]; then
  log_warning "Partitions non visibles via ${LOOP_DEVICE}, utilisation de kpartx (fallback)"
  kpartx -av "$BASE_IMAGE"
  sleep 2
  MAPPER_BASENAME=$(basename "$LOOP_DEVICE")
  BOOT_PART="/dev/mapper/${MAPPER_BASENAME}p1"
  ROOT_PART="/dev/mapper/${MAPPER_BASENAME}p2"
  USE_KPARTX=1
else
  BOOT_PART="${LOOP_DEVICE}p1"
  ROOT_PART="${LOOP_DEVICE}p2"
  USE_KPARTX=0
fi

log_info "Boot partition: $BOOT_PART"
log_info "Root partition: $ROOT_PART"

if [ ! -e "$BOOT_PART" ] || [ ! -e "$ROOT_PART" ]; then
  log_error "Impossible de trouver les partitions (p1/p2) après plusieurs tentatives"
  exit 1
fi

# Redimensionner le FS root (e2fsck + resize2fs)
log_info "Redimensionnement du système de fichiers..."
e2fsck -f -y "$ROOT_PART" || true
resize2fs "$ROOT_PART"

# Monter les partitions (Bookworm/Trixie: /boot/firmware)
log_info "Montage des partitions dans le chroot..."
mount "$ROOT_PART" "$MOUNT_DIR"
mkdir -p "${MOUNT_DIR}/boot/firmware"
mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"
log_success "Image montée sur $MOUNT_DIR"

# Préparer le chroot
log_info "Préparation du chroot..."
cp /etc/resolv.conf "${MOUNT_DIR}/etc/resolv.conf"
mount -t proc proc "${MOUNT_DIR}/proc"
mount -t sysfs sys "${MOUNT_DIR}/sys"
mount -o bind /dev "${MOUNT_DIR}/dev"
mount -t devpts devpts "${MOUNT_DIR}/dev/pts"

# Pousser config et scripts dans le chroot
log_info "Injection des scripts dans le chroot..."
cp "${BUILD_DIR}/scripts/customize-os.sh" "${MOUNT_DIR}/tmp/customize-os.sh"
cp "${BUILD_DIR}/scripts/install-wifi-connect.sh" "${MOUNT_DIR}/tmp/install-wifi-connect.sh"
cp "${BUILD_DIR}/scripts/install-runtipi.sh" "${MOUNT_DIR}/tmp/install-runtipi.sh"
cp "${BUILD_DIR}/scripts/setup-services.sh" "${MOUNT_DIR}/tmp/setup-services.sh"
cp "${CONFIG_FILE}" "${MOUNT_DIR}/tmp/config.yml"
chmod +x "${MOUNT_DIR}/tmp/"*.sh

# Customisation OS (packages, docker, utilisateur, page statut)
log_info "Customisation du système (chroot)..."
chroot "${MOUNT_DIR}" /bin/bash -lc "/tmp/customize-os.sh"

# Installer WiFi-Connect + portail captif
log_info "Installation WiFi-Connect (chroot)..."
chroot "${MOUNT_DIR}" /bin/bash -lc "/tmp/install-wifi-connect.sh"

# Déployer services (wifi-connect, runtipi-installer, lighttpd)
log_info "Configuration des services (chroot)..."
chroot "${MOUNT_DIR}" /bin/bash -lc "/tmp/setup-services.sh"

# Nettoyage chroot
log_info "Nettoyage du chroot..."
rm -f "${MOUNT_DIR}/tmp/"*.sh "${MOUNT_DIR}/tmp/config.yml" 2>/dev/null || true
chroot "${MOUNT_DIR}" apt-get clean
rm -rf "${MOUNT_DIR}/var/cache/apt/archives/"*.deb 2>/dev/null || true

# Démontage (déclenché par trap aussi)
log_info "Démontage des partitions..."
umount "${MOUNT_DIR}/dev/pts" || true
umount "${MOUNT_DIR}/dev" || true
umount "${MOUNT_DIR}/sys" || true
umount "${MOUNT_DIR}/proc" || true
umount "${MOUNT_DIR}/boot/firmware" || true
umount "${MOUNT_DIR}" || true

# Nettoyer mappings si kpartx
if [ "${USE_KPARTX}" = "1" ]; then
  kpartx -d "$BASE_IMAGE" || true
fi

# Détacher loop
losetup -d "${LOOP_DEVICE}" || true
LOOP_DEVICE=""

# Préparer la sortie
OUTPUT_NAME="${OUTPUT_NAME:-RuntipiOS-$(date +%Y%m%d)}-${CONFIG_raspios_arch}"
FINAL_IMAGE="${OUTPUT_DIR}/${OUTPUT_NAME}.img"

log_info "Préparation de l'image finale..."
cp "$BASE_IMAGE" "$FINAL_IMAGE"
log_success "Image copiée: $(basename "$FINAL_IMAGE")"

# Compression si activée
if [ "${CONFIG_build_compress}" = "true" ]; then
  log_info "Compression (${CONFIG_build_compression_format})..."
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
      rm -f "$FINAL_IMAGE"
      FINAL_IMAGE="${FINAL_IMAGE}.zip"
      ;;
    *)
      log_warning "Format inconnu: ${CONFIG_build_compression_format}"
      ;;
  esac
  log_success "Image compressée: $(basename "$FINAL_IMAGE")"
fi

# Résumé
log_success "Build terminé avec succès"
echo "Image finale: $FINAL_IMAGE"
echo "Taille: $(du -h "$FINAL_IMAGE" | cut -f1)"
echo "Emplacement: $FINAL_IMAGE"
