#!/bin/bash -e
# pi-gen 00-run.sh — Installe et configure tipi-setup dans le rootfs
# IMPORTANT : nommé 00-run.sh (avec préfixe numérique) comme requis par pi-gen

# ---- Arborescence ----
install -v -d "${ROOTFS_DIR}/opt/tipi-setup/templates"
install -v -d "${ROOTFS_DIR}/var/lib/tipi-setup"
install -v -d "${ROOTFS_DIR}/etc/hostapd"

# ---- Fichiers de l'application ----
install -v -m 755 files/start.sh                          "${ROOTFS_DIR}/opt/tipi-setup/start.sh"
install -v -m 644 files/app/app.py                        "${ROOTFS_DIR}/opt/tipi-setup/app.py"
install -v -m 644 files/app/setup.py                      "${ROOTFS_DIR}/opt/tipi-setup/setup.py"
install -v -m 644 files/app/translations.py               "${ROOTFS_DIR}/opt/tipi-setup/translations.py"
install -v -m 644 files/app/templates/base.html           "${ROOTFS_DIR}/opt/tipi-setup/templates/base.html"
install -v -m 644 files/app/templates/wifi.html           "${ROOTFS_DIR}/opt/tipi-setup/templates/wifi.html"
install -v -m 644 files/app/templates/configure.html      "${ROOTFS_DIR}/opt/tipi-setup/templates/configure.html"
install -v -m 644 files/app/templates/progress.html       "${ROOTFS_DIR}/opt/tipi-setup/templates/progress.html"
install -d                                                 "${ROOTFS_DIR}/opt/tipi-setup/static"
install -v -m 644 files/app/static/favicon.ico            "${ROOTFS_DIR}/opt/tipi-setup/static/favicon.ico"

# ---- Systemd service ----
install -v -m 644 files/tipi-setup.service                "${ROOTFS_DIR}/etc/systemd/system/tipi-setup.service"
install -v -m 644 files/tipi-runtipi-retry.service        "${ROOTFS_DIR}/etc/systemd/system/tipi-runtipi-retry.service"
install -v -m 755 files/retry-runtipi.sh                  "${ROOTFS_DIR}/opt/tipi-setup/retry-runtipi.sh"

# ---- hostapd : configuration du hotspot (country_code=US natif) ----
# Ref : même approche que RaspAP — seule méthode fiable pour brcmfmac (RPi 4/5)
install -v -m 600 files/hostapd.conf                      "${ROOTFS_DIR}/etc/hostapd/tipi-hostapd.conf"

# ---- Marqueur de premier démarrage ----
touch "${ROOTFS_DIR}/var/lib/tipi-setup/.not-configured"

# ---- Activation dans le chroot ----
on_chroot << EOF
set -x  # afficher chaque commande exécutée dans les logs pi-gen

# ---- Neutraliser le wizard de premier démarrage RPi OS ----
systemctl mask userconfig.service || true
systemctl mask rpi-first-boot-wizard.service || true
rm -f /lib/systemd/system/userconfig.service \
      /lib/systemd/system/rpi-first-boot-wizard.service \
      /etc/systemd/system/userconfig.service \
      /etc/xdg/autostart/piwiz.desktop 2>/dev/null || true

# ---- Désactiver le service hostapd système (on le lance depuis start.sh) ----
systemctl disable hostapd.service 2>/dev/null || true
systemctl mask hostapd.service    2>/dev/null || true

# ---- Désactiver le service wpa_supplicant standalone (NM le gère en interne) ----
systemctl disable wpa_supplicant.service 2>/dev/null || true

# ---- Activer le service tipi-setup ----
systemctl enable tipi-setup.service
systemctl enable tipi-runtipi-retry.service
systemctl enable avahi-daemon.service
# ---- Activer SSH (désactivé par défaut sur Trixie) ----
systemctl enable ssh.service

# Configurer nsswitch pour résoudre les noms .local via mDNS
sed -i 's/^hosts:.*/hosts:          files mdns4_minimal [NOTFOUND=return] dns/' /etc/nsswitch.conf

# Hostname de provisionnement (sera remplacé via portail web)
echo "tipisetup" > /etc/hostname
sed -i '/127\.0\.1\.1/d' /etc/hosts
echo "127.0.1.1   tipisetup" >> /etc/hosts

set +x
EOF
