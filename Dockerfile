# Utilise une base Debian stable et légère
FROM debian:bookworm-slim

# Arguments pour les métadonnées de l'image
ARG BUILD_DATE
ARG VERSION

# Labels pour décrire l'image (bonnes pratiques)
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.title="RuntipiOS Builder"
LABEL org.opencontainers.image.description="Builder to create custom Raspberry Pi OS images with Runtipi"

# Installe tous les outils nécessaires pour le build et nettoie le cache apt
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Outils de base et de téléchargement
    wget curl git ca-certificates gnupg \
    # Outils pour la cross-compilation ARM
    debootstrap qemu-user-static binfmt-support \
    # Outils de manipulation de partitions et de systèmes de fichiers
    parted kpartx dosfstools e2fsprogs fdisk \
    # Outils de compression
    xz-utils gzip zip unzip \
    # Outils système (pour le chroot)
    systemd systemd-sysv \
    # Outils pour les scripts
    yq jq \
    && rm -rf /var/lib/apt/lists/*

# Création de l'arborescence de travail
RUN mkdir -p /build/scripts /build/output /build/work /build/mount

# Copie des scripts et application des permissions exécutables
COPY scripts/ /build/scripts/
RUN chmod +x /build/scripts/*.sh

# Définition du répertoire de travail par défaut
WORKDIR /build

# Commande par défaut lors du lancement du conteneur
CMD ["/bin/bash"]
