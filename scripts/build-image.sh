#!/bin/bash
# RuntipiOS Image Builder - Version Finale avec Toutes les Corrections
set -euo pipefail

# --- Fonctions de log ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Variables Globales ---
BUILD_DIR="/build"; WORK_DIR="${BUILD_DIR}/work"; MOUNT_DIR="${BUILD_DIR}/mount"; OUTPUT_DIR="${BUILD_DIR}/output"; CONFIG_FILE="${BUILD_DIR}/config.yml"
LOOP_DEVICE=""; USE_KPARTX=0; BOOT_PART=""; ROOT_PART=""; BASE_IMAGE=""

# --- Fonction de Nettoyage Robuste ---
cleanup() {
    set +e; log_info "Nettoyage en cours..."; sync
    umount -l "${MOUNT_DIR}/dev/pts" 2>/dev/null
    umount -l "${MOUNT_DIR}/dev" 2>/dev/null
    umount -l "${MOUNT_DIR}/sys" 2>/dev/null
    umount -l "${MOUNT_DIR}/proc" 2>/dev/null
    umount -l "${MOUNT_DIR}/boot/firmware" 2>/dev/null
    umount -l "${MOUNT_DIR}" 2>/dev/null
    if [ "${USE_KPARTX}" = "1" ] && [ -n "${BASE_IMAGE}" ] && [ -f "${BASE_IMAGE}" ]; then
        kpartx -d "${BASE_IMAGE}" 2>/dev/null
    fi
    if [ -n "${LOOP_DEVICE}" ]; then
        losetup -d "${LOOP_DEVICE}" 2>/dev/null
    fi
}
trap cleanup EXIT

# --- Parser YAML ---
parse_yaml() {
    local prefix=$2; local s='[[:space:]]*'; local w='[a-zA-Z0-9_]*'; local fs; fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s$|\1$fs\2$fs\3|p" -e "s|^\($s\)\($w\)$s:$s\(.*\)$s$|\1$fs\2$fs\3|p" "$1" |
    awk -F"$fs" '{ indent = length($1)/2; vname[indent] = $2; for (i in vname) {if (i > indent) {delete vname[i]}} if (length($3) > 0) { vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")} printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3); } }'
}

# --- Démarrage du Build ---
log_info "Chargement de la configuration..."
if [ ! -f "$CONFIG_FILE" ]; then log_error "Fichier config.yml introuvable !"; exit 1; fi
eval $(parse_yaml "$CONFIG_FILE" "CONFIG_")

# --- Initialiser les variables optionnelles ---
: "${CONFIG_packages_install:=}"
: "${CONFIG_packages_remove:=}"
: "${CONFIG_build_compress:=true}"
: "${CONFIG_build_compression_format:=xz}"

TARGET_ARCH="${CONFIG_raspios_arch}"

log_info "Création des répertoires..."
mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"

log_info "Téléchargement de Raspberry Pi OS..."
BASE_IMAGE="${WORK_DIR}/raspios-base.img"
if [ ! -f "$BASE_IMAGE" ]; then
    wget -O "${BASE_IMAGE}.xz" "$CONFIG_raspios_url"
    xz -d -k "${BASE_IMAGE}.xz"
fi

log_info "Agrandissement de l'image à ${CONFIG_build_image_size}GB..."
truncate -s "${CONFIG_build_image_size}G" "$BASE_IMAGE"
parted -s "$BASE_IMAGE" resizepart 2 100%

# --- Montage ---
log_info "Montage de l'image..."
LOOP_DEVICE=$(losetup -f --show -P "$BASE_IMAGE")
sleep 5

if [ -e "${LOOP_DEVICE}p1" ] && [ -e "${LOOP_DEVICE}p2" ]; then
    log_info "Partitions détectées directement."
    BOOT_PART="${LOOP_DEVICE}p1"
    ROOT_PART="${LOOP_DEVICE}p2"
    USE_KPARTX=0
else
    log_warning "Utilisation de kpartx..."
    USE_KPARTX=1
    KPARTX_OUTPUT=$(kpartx -avs "$BASE_IMAGE")
    sleep 5
    BOOT_MAPPER=$(echo "$KPARTX_OUTPUT" | awk '/^add map.*p1 / {print $3; exit}')
    ROOT_MAPPER=$(echo "$KPARTX_OUTPUT" | awk '/^add map.*p2 / {print $3; exit}')
    if [ -z "$BOOT_MAPPER" ] || [ -z "$ROOT_MAPPER" ]; then
        log_error "Extraction mappers échouée."
        echo "$KPARTX_OUTPUT"
        exit 1
    fi
    BOOT_PART="/dev/mapper/${BOOT_MAPPER}"
    ROOT_PART="/dev/mapper/${ROOT_MAPPER}"
fi

log_info "Vérification..."
if [ ! -b "${BOOT_PART}" ] || [ ! -b "${ROOT_PART}" ]; then
    log_error "Périphérique introuvable: ${BOOT_PART}, ${ROOT_PART}"
    ls -la /dev/mapper
    exit 1
fi
log_success "Périphériques trouvés !"

mount "$ROOT_PART" "$MOUNT_DIR"
mkdir -p "${MOUNT_DIR}/boot/firmware"
mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"
log_success "Partitions montées."

# --- Chroot avec /dev/pts ---
log_info "Préparation du chroot..."
cp /etc/resolv.conf "${MOUNT_DIR}/etc/"
if [ "$(uname -m)" != "$TARGET_ARCH" ]; then
    cp "/usr/bin/qemu-aarch64-static" "${MOUNT_DIR}/usr/bin/"
fi

mount -t proc proc "${MOUNT_DIR}/proc"
mount -t sysfs sys "${MOUNT_DIR}/sys"
mount -o bind /dev "${MOUNT_DIR}/dev"
mount -t devpts devpts "${MOUNT_DIR}/dev/pts"

log_success "Chroot préparé"

# --- Script de personnalisation ---
log_info "Génération du script de personnalisation..."
cat > "${MOUNT_DIR}/tmp/run.sh" <<'EOF'
#!/bin/bash
set -e

# Créer un log pour debug
LOG_FILE="/root/runtipios-build.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================"
echo "[CHROOT] Démarrage de la personnalisation"
echo "[CHROOT] Date: $(date)"
echo "============================================"

echo "[CHROOT] Configuration système..."
echo "${CONFIG_system_hostname}" > /etc/hostname
rm -f /etc/localtime && ln -sf "/usr/share/zoneinfo/${CONFIG_system_timezone}" /etc/localtime

# Configuration des locales
echo "[CHROOT] Configuration des locales..."
echo "LANG=${CONFIG_system_locale}" > /etc/default/locale
cat > /etc/locale.gen << 'LOCALE_EOF'
fr_FR.UTF-8 UTF-8
en_GB.UTF-8 UTF-8
LOCALE_EOF
locale-gen
echo "[CHROOT] ✓ Locales générés"
sed -i "s/XKBLAYOUT=.*/XKBLAYOUT=\"${CONFIG_system_keyboard_layout}\"/" /etc/default/keyboard
raspi-config nonint do_wifi_country "${CONFIG_system_wifi_country}"
echo "[CHROOT] ✓ Configuration système terminée"

echo "[CHROOT] Nettoyage et mise à jour..."
rm -f /etc/xdg/autostart/piwiz.desktop
touch /etc/cloud/cloud-init.disabled
apt-get update && apt-get -y upgrade

echo "[CHROOT] Installation des paquets système..."
apt-get install -y --no-install-recommends network-manager avahi-daemon openssh-server rfkill iw ${CONFIG_packages_install}
apt-get remove -y --purge ${CONFIG_packages_remove}

echo "============================================"
echo "[CHROOT] Création de l'utilisateur..."
echo "============================================"

# Créer l'utilisateur
if id "pi" &>/dev/null; then
    echo "[CHROOT] Renommage de l'utilisateur 'pi' en '${CONFIG_system_default_user}'..."
    usermod -l "${CONFIG_system_default_user}" pi
    usermod -d "/home/${CONFIG_system_default_user}" -m "${CONFIG_system_default_user}"
    groupmod -n "${CONFIG_system_default_user}" pi
else
    echo "[CHROOT] Création de l'utilisateur '${CONFIG_system_default_user}'..."
    useradd -m -s /bin/bash -G sudo,netdev "${CONFIG_system_default_user}"
fi

# Configuration du mot de passe
echo "[CHROOT] Configuration du mot de passe..."
echo "${CONFIG_system_default_user}:${CONFIG_system_default_password}" | chpasswd

# Vérification
if id "${CONFIG_system_default_user}" &>/dev/null; then
    echo "[CHROOT] ✓ Utilisateur créé avec succès"
    echo "[CHROOT] UID: $(id -u ${CONFIG_system_default_user})"
    echo "[CHROOT] Groupes: $(groups ${CONFIG_system_default_user})"
else
    echo "[CHROOT] ✗ ERREUR: Utilisateur non créé!"
    exit 1
fi

# Autologin si activé
if [ "${CONFIG_system_autologin}" = "true" ]; then
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${CONFIG_system_default_user} --noclear %I \$TERM
AUTOLOGIN
    echo "[CHROOT] ✓ Autologin configuré"
fi

# Sudo sans mot de passe
echo "${CONFIG_system_default_user} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/010_${CONFIG_system_default_user}-nopasswd"
chmod 440 "/etc/sudoers.d/010_${CONFIG_system_default_user}-nopasswd"

# SSH
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

echo "============================================"
echo "[CHROOT] Installation de WiFi-Connect (Balena)"
echo "============================================"

cd /tmp
TARGET_ARCH_WC=""
case "${CONFIG_raspios_arch}" in
    "armhf") TARGET_ARCH_WC="armv7hf";;
    "arm64") TARGET_ARCH_WC="aarch64";;
esac

DOWNLOAD_URL="https://github.com/balena-os/wifi-connect/releases/download/v${CONFIG_wifi_connect_version}/wifi-connect-v${CONFIG_wifi_connect_version}-linux-${TARGET_ARCH_WC}.tar.gz"

echo "[CHROOT] Architecture: ${TARGET_ARCH_WC}"
echo "[CHROOT] Version: ${CONFIG_wifi_connect_version}"
echo "[CHROOT] URL: ${DOWNLOAD_URL}"

curl -L --fail "$DOWNLOAD_URL" -o wc.tar.gz
mkdir -p wc-extract
tar -xzf wc.tar.gz -C wc-extract --strip-components=1
mv wc-extract/wifi-connect /usr/local/bin/
chmod +x /usr/local/bin/wifi-connect
rm -rf wc-extract wc.tar.gz

if [ -f /usr/local/bin/wifi-connect ]; then
    echo "[CHROOT] ✓ WiFi-Connect installé: $(ls -lh /usr/local/bin/wifi-connect)"
else
    echo "[CHROOT] ✗ ERREUR: WiFi-Connect non trouvé!"
    exit 1
fi

echo "============================================"
echo "[CHROOT] Création de l'interface captive..."
echo "============================================"

UI_DIR="/etc/runtipi/ui"
mkdir -p "$UI_DIR"

cat > "${UI_DIR}/index.html" << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>RuntipiOS WiFi Setup</title><style>body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background-color:#f4f6f8}.header{background:#fff;padding:20px;text-align:center;border-bottom:1px solid #e0e0e0}.logo{max-width:150px;height:auto}.info-box{background:#fff3cd;border-left:4px solid #ffeeba;padding:15px 20px;margin:20px;border-radius:8px;color:#664d03;text-align:center;font-size:14px}.instructions{padding:0 20px;text-align:center;color:#555}.instructions h2{margin-bottom:10px;color:#333}code{background:#e9ecef;padding:2px 6px;border-radius:4px}</style></head><body><div class="header"><img src="https://runtipi.io/img/logo.png" alt="Runtipi Logo" class="logo"></div><div class="info-box"><strong id="security-alert-title"></strong><br><span id="security-alert-text"></span><code>passwd</code></div><div class="instructions"><h2 id="instruction-title"></h2><p id="instruction-text"></p></div><script>const t={en:{"security-alert-title":"IMPORTANT SECURITY NOTICE","security-alert-text":"After setup, connect via SSH and change the default password by typing the command:","instruction-title":"Configure WiFi","instruction-text":"Please select your WiFi network from the list below and enter the password to connect."},fr:{"security-alert-title":"AVIS DE SÉCURITÉ IMPORTANT","security-alert-text":"Après la configuration, connectez-vous en SSH et changez le mot de passe par défaut avec la commande :","instruction-title":"Configurer le WiFi","instruction-text":"Veuillez sélectionner votre réseau WiFi dans la liste ci-dessous et entrer le mot de passe pour vous connecter."}},n=navigator.language.split("-")[0],o=t[n]||t.en;for(const e in o){const l=document.getElementById(e);l&&(l.innerHTML=o[e])}</script></body></html>
HTMLEOF

echo "[CHROOT] ✓ Interface captive créée"

echo "============================================"
echo "[CHROOT] Création des scripts de démarrage..."
echo "============================================"

cat > /usr/local/bin/runtipios-first-boot.sh << 'BOOTEOF'
#!/bin/bash
if [ -f /etc/runtipi/configured ]; then exit 0; fi
if nmcli -t g | grep -q "full"; then
    touch /etc/runtipi/configured
    systemctl start runtipi-installer.service
    systemctl disable --now runtipios-first-boot.service
else
    exec /usr/local/bin/wifi-connect --portal-ssid "${CONFIG_wifi_connect_ssid}" --ui-directory "/etc/runtipi/ui"
fi
BOOTEOF
chmod +x /usr/local/bin/runtipios-first-boot.sh

cat > /etc/systemd/system/expand-rootfs.service <<'E1'
[Unit]
Description=Expand Root Filesystem on First Boot
ConditionPathExists=!/etc/runtipi/expand-done
[Service]
Type=oneshot
ExecStart=/bin/bash -c "parted /dev/mmcblk0 resizepart 2 100% && resize2fs /dev/mmcblk0p2 && touch /etc/runtipi/expand-done"
[Install]
WantedBy=multi-user.target
E1

cat > /etc/systemd/system/runtipios-first-boot.service <<'E2'
[Unit]
Description=RuntipiOS First Boot Logic
After=network-online.target
[Service]
ExecStart=/usr/local/bin/runtipios-first-boot.sh
[Install]
WantedBy=multi-user.target
E2

cat > /etc/systemd/system/runtipi-installer.service <<'E3'
[Unit]
Description=Runtipi Automatic Installer
[Service]
Type=oneshot
ExecStart=/bin/bash -c "curl -L https://setup.runtipi.io | bash"
E3

echo "[CHROOT] ✓ Services créés"

cat > /etc/motd << 'MOTDEOF'
\033[1;34m
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║                          \033[1;32mRUNTIPIOS\033[1;34m                                   ║
║                     \033[1;37mHomeserver Management\033[1;34m                             ║
║                                                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║  \033[1;33m⚠️  IMPORTANT : Changez votre mot de passe SSH par défaut !\033[1;34m         ║
║       \033[1;37mPour cela, tapez simplement la commande : \033[1;36m`passwd`\033[1;34m             ║
╠═══════════════════════════════════════════════════════════════════════╣
║   \033[1;37m🌐 Accès Web: \033[4;36mhttp://runtipios.local\033[0m\033[1;34m (après installation)          ║
║   \033[1;37m🔐 Accès SSH: \033[4;36mssh ${CONFIG_system_default_user}@runtipios.local\033[0m\033[1;34m                          ║
╚═══════════════════════════════════════════════════════════════════════╝
\033[0m
MOTDEOF

echo "============================================"
echo "[CHROOT] ✓ Personnalisation terminée avec succès !"
echo "[CHROOT] Log sauvegardé dans: $LOG_FILE"
echo "============================================"
EOF

chmod +x "${MOUNT_DIR}/tmp/run.sh"

log_info "Exécution du script de personnalisation..."
chroot "$MOUNT_DIR" /bin/bash "/tmp/run.sh" || {
    log_error "Le script de personnalisation a échoué!"
    log_error "Vérifiez le fichier de log: /root/runtipios-build.log"
    exit 1
}

rm -f "${MOUNT_DIR}/tmp/run.sh"

log_info "Activation des services..."
for service in expand-rootfs.service runtipios-first-boot.service avahi-daemon.service; do
    ln -sf "/etc/systemd/system/${service}" "${MOUNT_DIR}/etc/systemd/system/multi-user.target.wants/${service}"
done

if echo "${CONFIG_packages_install}" | grep -q "unattended-upgrades"; then
    chroot "$MOUNT_DIR" dpkg-reconfigure -plow unattended-upgrades
fi

log_info "Nettoyage du chroot..."
chroot "$MOUNT_DIR" apt-get clean
cleanup; trap - EXIT

log_info "Copie de l'image finale..."
FINAL_IMAGE="${OUTPUT_DIR}/${OUTPUT_NAME:-RuntipiOS-$(date +%Y%m%d)}.img"
mv "$BASE_IMAGE" "$FINAL_IMAGE"

# --- Compression ---
log_info "Compression..."
CONFIG_build_compress=$(echo "${CONFIG_build_compress}" | tr -d '[:space:]')

if [ "${CONFIG_build_compress}" = "true" ]; then
    log_info "Compression en cours (format: ${CONFIG_build_compression_format})..."
    case "${CONFIG_build_compression_format}" in
        xz) xz -9 -T0 "$FINAL_IMAGE" ;;
        gz) gzip -9 "$FINAL_IMAGE" ;;
        zip) zip -9 -j "${FINAL_IMAGE}.zip" "$FINAL_IMAGE" && rm "$FINAL_IMAGE" ;;
    esac
    log_success "Compression terminée !"
fi

log_info "Suppression des fichiers temporaires..."
rm -rf "${WORK_DIR}"

if [ "${CONFIG_build_compress}" = "true" ]; then
    COMPRESSED_FILE=$(ls ${OUTPUT_DIR}/*.img.* 2>/dev/null | head -1)
    if [ -f "$COMPRESSED_FILE" ]; then
        FINAL_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
        log_success "✓ Image finale: $(basename $COMPRESSED_FILE) ($FINAL_SIZE)"
    fi
fi

log_success "════════════════════════════════════════════"
log_success "Build terminé avec succès !"
log_success "════════════════════════════════════════════"
