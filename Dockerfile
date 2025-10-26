FROM debian:bookworm-slim

# Install required packages for building the ISO
RUN apt-get update && apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    rsync \
    wget \
    curl \
    git \
    python3 \
    python3-yaml \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /build

# Copy build scripts and configuration
COPY build-config.yml /build/
COPY scripts/ /build/scripts/

# Set executable permissions
RUN chmod +x /build/scripts/*.sh

# Build script will be run with docker run
CMD ["/build/scripts/build-iso.sh"]
