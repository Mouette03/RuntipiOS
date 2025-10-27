FROM debian:bookworm-slim

ARG BUILD_DATE
ARG VERSION

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.title="RuntipiOS Builder"
LABEL org.opencontainers.image.description="Builder pour créer des images Raspberry Pi OS customisées avec Runtipi"

RUN apt-get update && apt-get install -y \
    wget curl git ca-certificates gnupg lsb-release \
    debootstrap qemu-user-static binfmt-support \
    parted kpartx dosfstools e2fsprogs fdisk gdisk mount \
    xz-utils gzip zip unzip \
    systemd systemd-sysv dbus \
    iproute2 iputils-ping \
    python3 python3-yaml python3-pip \
    build-essential jq \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /build/scripts /build/stages /build/output /build/work /build/mount

# Copier les scripts ET forcer les permissions en une seule couche
COPY scripts/ /build/scripts/
RUN find /build/scripts -name "*.sh" -exec chmod +x {} \; && \
    ls -la /build/scripts/

WORKDIR /build

CMD ["/bin/bash"]
