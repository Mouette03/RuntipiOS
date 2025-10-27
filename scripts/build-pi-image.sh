#!/bin/bash
set -euo pipefail

# Build a Raspberry Pi style .img (arm64) using debootstrap
# This script creates two partitions: FAT boot (for Pi firmware) and ext4 root
# It then bootstraps Debian arm64 into the root and copies firmware to the boot partition.

BUILD_DIR="/build"
OUTPUT_DIR="${BUILD_DIR}/output"
CHROOT_DIR="${BUILD_DIR}/chroot-pi"

# Load build variables from config
eval $(python3 /build/scripts/parse-config.py)

IMG_SIZE="4G"
IMG_NAME="${OUTPUT_DIR}/RuntipiOS-${ISO_VERSION:-1.0.0}-raspberry.img"
FIRMWARE_REPO="https://github.com/raspberrypi/firmware.git"

mkdir -p "$OUTPUT_DIR" "$CHROOT_DIR"

echo "==> Creating sparse image file: $IMG_NAME ($IMG_SIZE)"
truncate -s "$IMG_SIZE" "$IMG_NAME"

echo "==> Partitioning image (MBR for Pi boot: FAT + root)"
parted -s "$IMG_NAME" mklabel msdos
parted -s "$IMG_NAME" mkpart primary fat32 1MiB 256MiB
parted -s "$IMG_NAME" mkpart primary ext4 256MiB 100%

LOOP=$(losetup --show -fP "$IMG_NAME")
echo "Loop device: $LOOP"
sleep 1
LOOP_BS=$(basename "$LOOP")
KPARTX_ADDED=0

# Determine partition device names robustly
if [ -b "${LOOP}p1" ]; then
  BOOT_DEV=${LOOP}p1
  ROOT_DEV=${LOOP}p2
elif [ -b "${LOOP}1" ]; then
  BOOT_DEV=${LOOP}1
  ROOT_DEV=${LOOP}2
else
  echo "Partition devices not present, trying kpartx to map partitions"
  kpartx -av "$LOOP"
  KPARTX_ADDED=1
  if [ -b "/dev/mapper/${LOOP_BS}p1" ]; then
    BOOT_DEV="/dev/mapper/${LOOP_BS}p1"
    ROOT_DEV="/dev/mapper/${LOOP_BS}p2"
  else
    sleep 1
    if [ -b "/dev/mapper/${LOOP_BS}p1" ]; then
      BOOT_DEV="/dev/mapper/${LOOP_BS}p1"
      ROOT_DEV="/dev/mapper/${LOOP_BS}p2"
    else
      echo "ERROR: cannot find partition devices for $LOOP"
      losetup -d "$LOOP" || true
      exit 1
    fi
  fi
fi

echo "Creating filesystems"
mkfs.vfat -F32 "$BOOT_DEV"
mkfs.ext4 -F "$ROOT_DEV"

MNT_BOOT=$(mktemp -d)
MNT_ROOT=$(mktemp -d)
trap 'echo "Cleaning..."; umount "$MNT_BOOT" 2>/dev/null || true; umount "$MNT_ROOT" 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true; rm -rf "$MNT_BOOT" "$MNT_ROOT"' EXIT
trap 'echo "Cleaning..."; umount "$MNT_BOOT" 2>/dev/null || true; umount "$MNT_ROOT" 2>/dev/null || true; if [ "$KPARTX_ADDED" -eq 1 ]; then kpartx -d "$LOOP" 2>/dev/null || true; fi; losetup -d "$LOOP" 2>/dev/null || true; rm -rf "$MNT_BOOT" "$MNT_ROOT"' EXIT

mount "$ROOT_DEV" "$MNT_ROOT"
mount "$BOOT_DEV" "$MNT_BOOT"

echo "==> Bootstrapping Debian arm64 into rootfs"
debootstrap --arch=arm64 --foreign ${RELEASE} "$MNT_ROOT" http://deb.debian.org/debian/
cp /usr/bin/qemu-aarch64-static "$MNT_ROOT/usr/bin/"
chroot "$MNT_ROOT" /usr/bin/qemu-aarch64-static /debootstrap/debootstrap --second-stage || true


mount --bind /proc "$MNT_ROOT/proc"
mount --bind /sys "$MNT_ROOT/sys"
mount --bind /dev "$MNT_ROOT/dev"

# Installer le kernel arm64 et vérifier
echo "==> Installing linux-image-arm64 in chroot"
chroot "$MNT_ROOT" /usr/bin/qemu-aarch64-static /bin/bash -lc "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install -y linux-image-arm64 ssh network-manager python3 python3-pip python3-yaml"
echo "==> Kernel files in /boot:"
ls -l "$MNT_ROOT/boot"
KERNEL_ARM64=$(ls "$MNT_ROOT/boot" | grep 'vmlinuz-' | grep -v 'amd64' | head -1)
if [ -z "$KERNEL_ARM64" ]; then
  echo "ERROR: No arm64 kernel found in /boot."
  exit 1
fi

# Fetch Raspberry Pi firmware and copy boot files
TEMP_FW=$(mktemp -d)
if git ls-remote "$FIRMWARE_REPO" &>/dev/null; then
  echo "Cloning Raspberry Pi firmware (shallow)"
  git clone --depth 1 "$FIRMWARE_REPO" "$TEMP_FW"
  echo "Copying firmware to boot partition"
  cp -r "$TEMP_FW"/boot/* "$MNT_BOOT/" || true
  # Some firmwares expect overlays dir
  mkdir -p "$MNT_BOOT/overlays"
  cp -r "$TEMP_FW"/boot/overlays/* "$MNT_BOOT/overlays/" 2>/dev/null || true
  rm -rf "$TEMP_FW"
else
  echo "Warning: cannot fetch firmware repo; boot files may be missing"
fi

# Copy kernel and initrd from chroot /boot to boot partition
cp -r "$MNT_ROOT/boot"/* "$MNT_BOOT/" 2>/dev/null || true

# Create basic config.txt and cmdline.txt if missing
if [ ! -f "$MNT_BOOT/config.txt" ]; then
  cat > "$MNT_BOOT/config.txt" <<'EOF'
# Basic config for RuntipiOS
arm_64bit=1
enable_uart=1
EOF
fi
if [ ! -f "$MNT_BOOT/cmdline.txt" ]; then
  # cmdline: root on PARTUUID=... but we keep simple and rely on /dev/mmcblk0p2
  echo "console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rw rootwait" > "$MNT_BOOT/cmdline.txt"
fi

# Basic fstab
cat > "$MNT_ROOT/etc/fstab" <<EOF
/dev/mmcblk0p2 / ext4 defaults 0 1
/dev/mmcblk0p1 /boot vfat defaults 0 0
EOF

# Cleanup mounts
umount "$MNT_ROOT/proc" || true
umount "$MNT_ROOT/sys" || true
umount "$MNT_ROOT/dev" || true
sync

echo "Image created: $IMG_NAME"
cd "$OUTPUT_DIR"
sha256sum "$(basename "$IMG_NAME")" > SHA256SUMS

exit 0
