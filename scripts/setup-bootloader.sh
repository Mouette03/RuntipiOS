#!/bin/bash
set -e

ISO_DIR=$1

echo "==> Setting up bootloader..."

# Create bootloader directories
mkdir -p "${ISO_DIR}/isolinux"
mkdir -p "${ISO_DIR}/EFI/boot"

# Copy isolinux files
cp /usr/lib/ISOLINUX/isolinux.bin "${ISO_DIR}/isolinux/"
cp /usr/lib/syslinux/modules/bios/* "${ISO_DIR}/isolinux/"

# Create isolinux configuration
cat > "${ISO_DIR}/isolinux/isolinux.cfg" << 'EOF'
UI vesamenu.c32
TIMEOUT 100
DEFAULT runtipi

LABEL runtipi
    MENU LABEL RuntipiOS
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live components quiet splash

LABEL runtipi-nopersist
    MENU LABEL RuntipiOS (No Persistence)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live components nopersistence
EOF

# Setup UEFI boot
grub-mkstandalone \
    --format=x86_64-efi \
    --output="${ISO_DIR}/EFI/boot/bootx64.efi" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg" || true

# Create GRUB configuration
mkdir -p "${ISO_DIR}/boot/grub"
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
set timeout=5
set default=0

menuentry "RuntipiOS" {
    linux /live/vmlinuz boot=live components quiet splash
    initrd /live/initrd
}

menuentry "RuntipiOS (No Persistence)" {
    linux /live/vmlinuz boot=live components nopersistence
    initrd /live/initrd
}
EOF

echo "==> Bootloader setup complete!"
