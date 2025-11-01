#!/bin/bash
# RuntipiOS Image Builder - Version avec Montage Fiabilisé
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
    umount -l "${MOUNT_DIR}/dev/pts" 2>/dev/null; umount -l "${MOUNT_DIR}/dev" 2>/dev/null; umount -l "${MOUNT_DIR}/sys" 2>/dev/null; umount -l "${MOUNT_DIR}/proc" 2>/dev/null
    umount -l "${MOUNT_DIR}/boot/firmware" 2>/dev/null; umount -l "${MOUNT_DIR}" 2>/dev/null
    if [ "${USE_KPARTX}" = "1" ] && [ -n "${BASE_IMAGE}" ] && [ -f "${BASE_IMAGE}" ]; then kpartx -d "${BASE_IMAGE}" 2>/dev/null; fi
    if [ -n "${LOOP_DEVICE}" ]; then losetup -d "${LOOP_DEVICE}" 2>/dev/null; fi
}
trap cleanup EXIT

# --- Parser YAML (Hérité de votre version fonctionnelle) ---
parse_yaml() {
    local prefix=$2; local s='[[:space:]]*'; local w='[a-zA-Z0-9_]*'; local fs; fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s$|\1$fs\2$fs\3|p" -e "s|^\($s\)\($w\)$s:$s\(.*\)$s$|\1$fs\2$fs\3|p" "$1" |
    awk -F"$fs" '{ indent = length($1)/2; vname[indent] = $2; for (i in vname) {if (i > indent) {delete vname[i]}} if (length($3) > 0) { vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")} printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3); } }'
}

# --- Démarrage du Build ---
log_info "Chargement de la configuration depuis ${CONFIG_FILE}..."
if [ ! -f "$CONFIG_FILE" ]; then log_error "Fichier config.yml introuvable !"; exit 1; fi
eval $(parse_yaml "$CONFIG_FILE" "CONFIG_")
TARGET_ARCH="${CONFIG_raspios_arch}"

log_info "Création des répertoires de travail..."
mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"

log_info "Téléchargement de Raspberry Pi OS..."
BASE_IMAGE="${WORK_DIR}/raspios-base.img"
if [ ! -f "$BASE_IMAGE" ]; then wget -O "${BASE_IMAGE}.xz" "$CONFIG_raspios_url" && xz -d -k "${BASE_IMAGE}.xz"; fi

log_info "Agrandissement de l'image à ${CONFIG_build_image_size}GB..."
truncate -s "${CONFIG_build_image_size}G" "$BASE_IMAGE"
parted -s "$BASE_IMAGE" resizepart 2 100%

# --- Montage Robuste de l'Image ---
log_info "Montage de l'image..."
LOOP_DEVICE=$(losetup -f --show -P "$BASE_IMAGE")

# --- CORRECTION : PAUSE ET VÉRIFICATION ---
log_info "Attente de la disponibilité des partitions..."
sleep 5 # Pause de 5 secondes pour laisser le temps au noyau

if [ -e "${LOOP_DEVICE}p1" ] && [ -e "${LOOP_DEVICE}p2" ]; then
    log_info "Partitions détectées directement via losetup."
    BOOT_PART="${LOOP_DEVICE}p1"; ROOT_PART="${LOOP_DEVICE}p2"; USE_KPARTX=0
else
    log_warning "Partitions non détectées, utilisation de kpartx..."; USE_KPARTX=1
    KPARTX_OUTPUT=$(kpartx -avs "$BASE_IMAGE")
    sleep 5 # Pause supplémentaire après kpartx
    BOOT_MAPPER=$(echo "$KPARTX_OUTPUT" | awk '/p1/{print $3}'); ROOT_MAPPER=$(echo "$KPARTX_OUTPUT" | awk '/p2/{print $3}')
    BOOT_PART="/dev/mapper/${BOOT_MAPPER}"; ROOT_PART="/dev/mapper/${ROOT_MAPPER}"
fi

log_info "Vérification de l'existence des périphériques de partitions..."
if [ ! -b "${BOOT_PART}" ] || [ ! -b "${ROOT_PART}" ]; then
    log_error "Le périphérique de partition boot ou root est introuvable."
    log_error "Boot: ${BOOT_PART}, Root: ${ROOT_PART}"
    log_error "Contenu de /dev/mapper/ :"
    ls -la /dev/mapper
    exit 1
fi
log_success "Périphériques de partitions trouvés !"

mount "$ROOT_PART" "$MOUNT_DIR"; mkdir -p "${MOUNT_DIR}/boot/firmware"; mount "$BOOT_PART" "${MOUNT_DIR}/boot/firmware"
log_success "Partitions montées avec succès."

# --- Préparation du Chroot ---
log_info "Préparation du chroot..."
cp /etc/resolv.conf "${MOUNT_DIR}/etc/"; if [ "$(uname -m)" != "$TARGET_ARCH" ]; then cp "/usr/bin/qemu-aarch64-static" "${MOUNT_DIR}/usr/bin/"; fi
mount -t proc proc "${MOUNT_DIR}/proc"; mount -t sysfs sys "${MOUNT_DIR}/sys"; mount -o bind /dev "${MOUNT_DIR}/dev"

# --- Injection et Exécution du Script de Personnalisation ---
log_info "Génération et exécution du script de personnalisation dans le chroot..."
cat > "${MOUNT_DIR}/tmp/run.sh" <<EOF
#!/bin/bash
set -e
echo "${CONFIG_system_hostname}" > /etc/hostname
rm -f /etc/localtime && ln -sf "/usr/share/zoneinfo/${CONFIG_system_timezone}" /etc/localtime
echo "LANG=${CONFIG_system_locale}" > /etc/default/locale
sed -i "s/^# *${CONFIG_system_locale}/${CONFIG_system_locale}/" /etc/locale.gen && locale-gen
sed -i "s/XKBLAYOUT=.*/XKBLAYOUT=\"${CONFIG_system_keyboard_layout}\"/" /etc/default/keyboard
raspi-config nonint do_wifi_country "${CONFIG_system_wifi_country}"
rm -f /etc/xdg/autostart/piwiz.desktop; touch /etc/cloud/cloud-init.disabled
apt-get update && apt-get -y upgrade
apt-get install -y --no-install-recommends network-manager avahi-daemon openssh-server rfkill iw ${CONFIG_packages_install}
apt-get remove -y --purge ${CONFIG_packages_remove}
if id "pi" &>/dev/null; then usermod -l "${CONFIG_system_default_user}" pi && usermod -d "/home/${CONFIG_system_default_user}" -m "${CONFIG_system_default_user}" && groupmod -n "${CONFIG_system_default_user}" pi; else useradd -m -s /bin/bash -G sudo,netdev "${CONFIG_system_default_user}"; fi
echo "${CONFIG_system_default_user}:${CONFIG_system_default_password}" | chpasswd
if [ "${CONFIG_system_autologin}" = "true" ]; then mkdir -p /etc/systemd/system/getty@tty1.service.d; echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin ${CONFIG_system_default_user} --noclear %I \\\$TERM" > /etc/systemd/system/getty@tty1.service.d/autologin.conf; fi
echo "${CONFIG_system_default_user} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/010_${CONFIG_system_default_user}-nopasswd"; sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
cd /tmp
TARGET_ARCH_WC=""; case "${CONFIG_raspios_arch}" in "armhf") TARGET_ARCH_WC="armv7hf";; "arm64") TARGET_ARCH_WC="aarch64";; esac
DOWNLOAD_URL="https://github.com/balena-os/wifi-connect/releases/download/v${CONFIG_wifi_connect_version}/wifi-connect-v${CONFIG_wifi_connect_version}-linux-\${TARGET_ARCH_WC}.tar.gz"
curl -L --fail "\$DOWNLOAD_URL" -o wc.tar.gz
mkdir -p wc-extract; tar -xzf wc.tar.gz -C wc-extract --strip-components=1
mv wc-extract/wifi-connect /usr/local/bin/; chmod +x /usr/local/bin/wifi-connect
rm -rf wc-extract wc.tar.gz
UI_DIR="/etc/runtipi/ui"
mkdir -p "\$UI_DIR"
cat > "\${UI_DIR}/index.html" << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>RuntipiOS WiFi Setup</title><style>body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background-color:#f4f6f8}.header{background:#fff;padding:20px;text-align:center;border-bottom:1px solid #e0e0e0}.logo{max-width:150px;height:auto}.info-box{background:#fff3cd;border-left:4px solid #ffeeba;padding:15px 20px;margin:20px;border-radius:8px;color:#664d03;text-align:center;font-size:14px}.instructions{padding:0 20px;text-align:center;color:#555}.instructions h2{margin-bottom:10px;color:#333}code{background:#e9ecef;padding:2px 6px;border-radius:4px}</style></head><body><div class="header"><img src="https://runtipi.io/img/logo.png" alt="Runtipi Logo" class="logo"></div><div class="info-box"><strong id="security-alert-title"></strong><br><span id="security-alert-text"></span><code>passwd</code></div><div class="instructions"><h2 id="instruction-title"></h2><p id="instruction-text"></p></div><script>const t={en:{"security-alert-title":"IMPORTANT SECURITY NOTICE","security-alert-text":"After setup, connect via SSH and change the default password by typing the command:","instruction-title":"Configure WiFi","instruction-text":"Please select your WiFi network from the list below and enter the password to connect."},fr:{"security-alert-title":"AVIS DE SÉCURITÉ IMPORTANT","security-alert-text":"Après la configuration, connectez-vous en SSH et changez le mot de passe par défaut avec la commande :","instruction-title":"Configurer le WiFi","instruction-text":"Veuillez sélectionner votre réseau WiFi dans la liste ci-dessous et entrer le mot de passe pour vous connecter."}},n=navigator.language.split("-")[0],o=t[n]||t.en;for(const e in o){const l=document.getElementById(e);l&&(l.innerHTML=o[e])}</script></body></html>
HTMLEOF
cat > /usr/local/bin/runtipios-first-boot.sh << BOOTEOF
#!/bin/bash
if [ -f /etc/runtipi/configured ]; then exit 0; fi
if nmcli -t g | grep -q "full"; then touch /etc/runtipi/configured; systemctl start runtipi-installer.service; systemctl disable --now runtipios-first-boot.service; else exec /usr/local/bin/wifi-connect --portal-ssid "${CONFIG_wifi_connect_ssid}" --ui-directory "/etc/runtipi/ui"; fi
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
EOF
chmod +x "${MOUNT_DIR}/tmp/run.sh"
chroot "$MOUNT_DIR" /bin/bash "/tmp/run.sh"
rm -f "${MOUNT_DIR}/tmp/run.sh"

# --- Activation services ---
log_info "Activation des services..."
for service in expand-rootfs.service runtipios-first-boot.service avahi-daemon.service; do ln -sf "/etc/systemd/system/${service}" "${MOUNT_DIR}/etc/systemd/system/multi-user.target.wants/${service}"; done
if echo "${CONFIG_packages_install}" | grep -q "unattended-upgrades"; then chroot "$MOUNT_DIR" dpkg-reconfigure -plow unattended-upgrades; fi

# --- Finalisation ---
log_info "Nettoyage..."
chroot "$MOUNT_DIR" apt-get clean
cleanup; trap - EXIT

log_info "Copie de l'image finale..."
FINAL_IMAGE="${OUTPUT_DIR}/${OUTPUT_NAME:-RuntipiOS-$(date +%Y%m%d)}.img"
mv "$BASE_IMAGE" "$FINAL_IMAGE"

# --- Compression ---
if [ "${CONFIG_build_compress:-false}" = "true" ]; then
    log_info "Compression..."
    case "${CONFIG_build_compression_format}" in
        xz) xz -T0 "$FINAL_IMAGE" ;;
        gz) gzip "$FINAL_IMAGE" ;;
        zip) zip -j "${FINAL_IMAGE}.zip" "$FINAL_IMAGE" && rm "$FINAL_IMAGE" ;;
    esac
fi

log_success "Build terminé avec succès !"
