FROM debian:bookworm-slim

# Install required packages for building the ISO
RUN apt-get update && apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-efi \
    grub-pc-bin \
    mtools \
    dosfstools \
    rsync \
    wget \
    curl \
    git \
    python3 \
    python3-yaml \
    # Tools for building ARM images
    qemu-user-static \
    binfmt-support \
    kpartx \
    parted \
    e2fsprogs \
    # dosfstools already installed above
    kmod \
    util-linux \
    # grub-efi packages are architecture-specific and will be installed inside
    # the target chroot (arm64 or amd64) rather than in the builder image.
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /build

# Copy build scripts and configuration
COPY build-config.yml /build/
COPY scripts/ /build/scripts/

# Set executable permissions for all scripts including subdirectories
RUN find /build/scripts -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;

# Build script will be run with docker run
CMD ["/build/scripts/build-iso.sh"]
