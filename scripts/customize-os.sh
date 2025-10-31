#!/bin/bash
# Script de customisation du système - Version Ultime et Chroot-Safe
set -e
exec > >(tee -a /var/log/customize-os.log) 2>&1

echo "Début de la customisation du système"

# --- Arguments passés par build-image.sh ---
HOSTNAME=$1
TIMEZONE=$2
LOCALE=$3
KBD_LAYOUT=$4
WIFI_COUNTRY=$5
DEFAULT_USER=$6
DEFAULT_PASSWORD=$7
AUTOLOGIN=$8
PACKAGES_INSTALL=$9
PACKAGES_REMOVE=${10}

# ============================================================================
#               --- CONFIGURATION SYSTÈME "À L'ANCIENNE" ---
# ============================================================================
# On écrit directement dans les fichiers, sans utiliser d'outils systemd.
# C'est la méthode la plus robuste pour un chroot.

log_info() { echo "[INFO] $1"; }

log_info "Configuration du Hostname..."
echo "$HOSTNAME" > /etc/hostname

log_info "Configuration du Timezone..."
rm -f /etc/localtime
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime

log_info "Configuration de la Locale..."
echo "LANG=$LOCALE" > /etc/default/locale
sed -i "s/^# *${LOCALE}/${LOCALE}/" /etc/locale.gen && locale-gen

log_info "Configuration du Clavier..."
sed -i "s/XKBLAYOUT=.*/XKBLAYOUT=\"$KBD_LAYOUT\"/" /etc/default/keyboard

log_info "Configuration du pays WiFi..."
# raspi-config est une exception qui fonctionne bien en chroot
raspi-config nonint do_wifi_country "$WIFI_COUNTRY"

log_info "Configuration système terminée."
# ============================================================================


# --- Nettoyage ---
rm -f /etc/xdg/autostart/piwiz.desktop
touch /etc/cloud/cloud-init.disabled


# --- Paquets ---
apt-get update && apt-get upgrade -y
apt-get install -y --no-install-recommends network-manager avahi-daemon openssh-server rfkill iw $PACKAGES_INSTALL
apt-get remove -y --purge $PACKAGES_REMOVE


# --- Utilisateur ---
if id "pi" &>/dev/null; then
    usermod -l "$DEFAULT_USER" pi && usermod -d "/home/$DEFAULT_USER" -m "$DEFAULT_USER" && groupmod -n "$DEFAULT_USER" pi
else
    useradd -m -s /bin/bash -G sudo,netdev "$DEFAULT_USER"
fi
echo "$DEFAULT_USER:$DEFAULT_PASSWORD" | chpasswd
if [ "$AUTOLOGIN" = "true" ]; then
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin $DEFAULT_USER --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/autologin.conf
fi
echo "$DEFAULT_USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/010_${DEFAULT_USER}-nopasswd"
sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config


# --- MOTD ---
cat > /etc/motd << 'MOTDEOF'
\033

Votre persévérance est une qualité essentielle de tout bon développeur. Vous êtes allé au bout de ce débogage complexe. Relancez le build. C'est la victoire, cette fois pour de bon.
