#!/bin/bash
set -euo pipefail

# Build a generic UEFI-bootable arm64 .img using debootstrap
# Usage: run inside builder container with /build as working dir

BUILD_DIR="/build"
OUTPUT_DIR="${BUILD_DIR}/output"
CHROOT_DIR="${BUILD_DIR}/chroot-arm"
IMG_SIZE="4G"  # default size, can be overridden by env IMAGE_SIZE
IMG_NAME="${OUTPUT_DIR}/RuntipiOS-${ISO_VERSION:-1.0.0}-arm64.img"

mkdir -p "$OUTPUT_DIR" "$CHROOT_DIR"

echo "==> Creating sparse image file: $IMG_NAME ($IMG_SIZE)"
truncate -s "$IMG_SIZE" "$IMG_NAME"

echo "==> Partitioning image (GPT: EFI FAT + root ext4)"
parted -s "$IMG_NAME" mklabel gpt
parted -s "$IMG_NAME" mkpart primary fat32 1MiB 512MiB
parted -s "$IMG_NAME" mkpart primary ext4 512MiB 100%
parted -s "$IMG_NAME" set 1 boot on

# Attach loop device
LOOP=$(losetup --show -fP "$IMG_NAME")
echo "Loop device: $LOOP"
# Wait a moment for the kernel to create partition devices
sleep 1
LOOP_BS=$(basename "$LOOP")
KPARTX_ADDED=0

# Prefer ${loop}p1 naming, fallback to ${loop}1, then try kpartx mapping
if [ -b "${LOOP}p1" ]; then
  EFI_DEV=${LOOP}p1
  ROOT_DEV=${LOOP}p2
elif [ -b "${LOOP}1" ]; then
  EFI_DEV=${LOOP}1
  ROOT_DEV=${LOOP}2
else
  echo "Partition devices not present, trying kpartx to map partitions"
  kpartx -av "$LOOP"
  KPARTX_ADDED=1
  # mapper devices look like /dev/mapper/loop0p1
  if [ -b "/dev/mapper/${LOOP_BS}p1" ]; then
    EFI_DEV="/dev/mapper/${LOOP_BS}p1"
    ROOT_DEV="/dev/mapper/${LOOP_BS}p2"
  else
    # give a short wait and re-check
    sleep 1
    if [ -b "/dev/mapper/${LOOP_BS}p1" ]; then
      EFI_DEV="/dev/mapper/${LOOP_BS}p1"
      ROOT_DEV="/dev/mapper/${LOOP_BS}p2"
    else
      echo "ERROR: cannot find partition devices for $LOOP"
      losetup -d "$LOOP" || true
      exit 1
    fi
  fi
fi

echo "EFI_DEV=$EFI_DEV, ROOT_DEV=$ROOT_DEV"

echo "==> Creating filesystems"
mkfs.vfat -F32 "$EFI_DEV"
mkfs.ext4 -F "$ROOT_DEV"

MNT_EFI=$(mktemp -d)
MNT_ROOT=$(mktemp -d)

trap 'echo "Cleaning..."; umount "$MNT_EFI" 2>/dev/null || true; umount "$MNT_ROOT" 2>/dev/null || true; if [ "$KPARTX_ADDED" -eq 1 ]; then kpartx -d "$LOOP" 2>/dev/null || true; fi; losetup -d "$LOOP" 2>/dev/null || true; rm -rf "$MNT_EFI" "$MNT_ROOT"' EXIT

mount "$ROOT_DEV" "$MNT_ROOT"
mount "$EFI_DEV" "$MNT_EFI"

echo "==> Bootstrapping Debian arm64 into rootfs"
# Use debootstrap foreign + qemu for second stage
debootstrap --arch=arm64 --foreign ${RELEASE} "$MNT_ROOT" http://deb.debian.org/debian/

# Copy qemu static into chroot for second stage
cp /usr/bin/qemu-aarch64-static "$MNT_ROOT/usr/bin/"
chroot "$MNT_ROOT" /usr/bin/qemu-aarch64-static /debootstrap/debootstrap --second-stage || true

# Minimal apt configuration inside chroot
cat > "$MNT_ROOT/etc/apt/apt.conf.d/99noconfirm" <<'EOF'
APT::Acquire::Retries "3";
DPkg::Options {"--force-confold"; "--force-confdef"; };
EOF

mount --bind /proc "$MNT_ROOT/proc"
mount --bind /sys "$MNT_ROOT/sys"
mount --bind /dev "$MNT_ROOT/dev"

chroot "$MNT_ROOT" /usr/bin/qemu-aarch64-static /bin/bash -lc "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install -y --no-install-recommends linux-image-arm64 grub-efi-arm64 shim-signed systemd-sysv --allow-unauthenticated || apt-get install -y --no-install-recommends linux-image-arm64 grub-efi-arm64 systemd-sysv || true"

# Install grub into the EFI partition
echo "==> Installing GRUB (UEFI)"
mkdir -p "$MNT_EFI/EFI/BOOT"
chroot "$MNT_ROOT" /usr/bin/qemu-aarch64-static /bin/bash -lc "grub-install --target=arm64-efi --efi-directory=/boot/efi --boot-directory=/boot --removable --no-nvram || true"

# Some GRUB packages expect /boot/efi path; create symlink
mkdir -p "$MNT_ROOT/boot/efi"
# copy kernel and initrd to /boot
chroot "$MNT_ROOT" /usr/bin/qemu-aarch64-static /bin/bash -lc "update-initramfs -u || true; ls -l /boot || true"

# Copy /boot files to EFI if necessary
cp -r "$MNT_ROOT/boot"/* "$MNT_EFI/" 2>/dev/null || true

# Basic fstab and cmdline
cat > "$MNT_ROOT/etc/fstab" <<EOF
/dev/root / ext4 defaults 0 1
EOF

# Cleanup mounts
umount "$MNT_ROOT/proc" || true
umount "$MNT_ROOT/sys" || true
umount "$MNT_ROOT/dev" || true

echo "==> Sync and finish"
sync

# detach loop in trap

echo "Image created: $IMG_NAME"

# produce checksum
cd "$OUTPUT_DIR"
sha256sum "$(basename "$IMG_NAME")" > SHA256SUMS

exit 0
