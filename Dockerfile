# Dockerfile

```dockerfile
FROM debian:bookworm-slim

ARG BUILD_DATE
ARG VERSION

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.title="RuntipiOS Builder"
LABEL org.opencontainers.image.description="Builder pour créer des images Raspberry Pi OS customisées avec Runtipi"

# Installation des dépendances pour la création d'images
RUN apt-get update && apt-get install -y \
    # Outils de base
    wget \
    curl \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    # Outils pour créer des images
    debootstrap \
    qemu-user-static \
    binfmt-support \
    parted \
    kpartx \
    dosfstools \
    e2fsprogs \
    fdisk \
    gdisk \
    mount \
    # Compression
    xz-utils \
    gzip \
    zip \
    unzip \
    # Outils système
    systemd \
    systemd-sysv \
    dbus \
    # Outils réseau
    iproute2 \
    iputils-ping \
    # Parser YAML
    python3 \
    python3-yaml \
    python3-pip \
    # Outils de développement
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Créer la structure de répertoires
RUN mkdir -p /build/scripts \
    /build/stages \
    /build/output \
    /build/work \
    /build/mount

# Copier les scripts
COPY scripts/ /build/scripts/
RUN chmod +x /build/scripts/*.sh

# Définir le répertoire de travail
WORKDIR /build

# Point d'entrée par défaut
CMD ["/bin/bash"]
```
