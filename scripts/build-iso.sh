#!/bin/bash
set -e

# RuntipiOS ISO Builder
# This script builds a custom Debian-based ISO with Runtipi pre-configured

BUILD_DIR="/build"
OUTPUT_DIR="${BUILD_DIR}/output"
CHROOT_DIR="${BUILD_DIR}/chroot"
ISO_DIR="${BUILD_DIR}/iso"

echo "==> Starting RuntipiOS build process..."

# Create output directories
mkdir -p "${OUTPUT_DIR}" "${CHROOT_DIR}" "${ISO_DIR}"

# Parse configuration
echo "==> Parsing build configuration..."
python3 "${BUILD_DIR}/scripts/parse-config.py" > /tmp/build-vars.sh
source /tmp/build-vars.sh

# Bootstrap the base system
echo "==> Bootstrapping Debian base system..."
debootstrap --arch="${ARCH}" "${RELEASE}" "${CHROOT_DIR}" http://deb.debian.org/debian/

# Configure the chroot environment
echo "==> Configuring chroot environment..."
mount --bind /dev "${CHROOT_DIR}/dev"
mount --bind /proc "${CHROOT_DIR}/proc"
mount --bind /sys "${CHROOT_DIR}/sys"

# Copy configuration files into chroot
cp "${BUILD_DIR}/scripts/chroot-setup.sh" "${CHROOT_DIR}/tmp/"
cp "${BUILD_DIR}/build-config.yml" "${CHROOT_DIR}/tmp/"
cp -r "${BUILD_DIR}/scripts/firstboot" "${CHROOT_DIR}/tmp/" || true
cp -r "${BUILD_DIR}/scripts/installer" "${CHROOT_DIR}/tmp/" || true

# Run setup inside chroot
echo "==> Running setup inside chroot..."
chroot "${CHROOT_DIR}" /bin/bash /tmp/chroot-setup.sh

# Unmount chroot
echo "==> Cleaning up chroot mounts..."
umount "${CHROOT_DIR}/dev" || true
umount "${CHROOT_DIR}/proc" || true
umount "${CHROOT_DIR}/sys" || true

# Create squashfs filesystem
echo "==> Creating squashfs filesystem..."
mkdir -p "${ISO_DIR}/live"
mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/live/filesystem.squashfs" -comp xz -b 1M

# Copy kernel and initrd
echo "==> Copying kernel and initrd..."
cp "${CHROOT_DIR}/boot/vmlinuz-"* "${ISO_DIR}/live/vmlinuz"
cp "${CHROOT_DIR}/boot/initrd.img-"* "${ISO_DIR}/live/initrd"

# Setup bootloader
echo "==> Setting up bootloader..."
"${BUILD_DIR}/scripts/setup-bootloader.sh" "${ISO_DIR}"

# Create ISO
echo "==> Creating ISO image..."
ISO_NAME="RuntipiOS-${ISO_VERSION:-1.0.0}-${ARCH}.iso"
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "${ISO_LABEL}" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-alt-boot \
    -e EFI/boot/bootx64.efi \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output "${OUTPUT_DIR}/${ISO_NAME}" \
    "${ISO_DIR}"

echo "==> Build complete!"
echo "==> ISO created: ${OUTPUT_DIR}/${ISO_NAME}"
ls -lh "${OUTPUT_DIR}/${ISO_NAME}"
