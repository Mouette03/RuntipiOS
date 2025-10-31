#!/bin/bash
# Script de customisation du système d'exploitation - Version Robuste
set -e
exec > >(tee -a /var/log/customize-os.log) 2>&1

echo "Début de la customisation du système - RuntipiOS"
CONFIG_FILE="/tmp/config.yml"
if [ ! -f "$CONFIG_FILE" ]; then echo "ERREUR: config.yml introuvable !" && exit 1; fi
eval "$(yq -o=shell "$CONFIG_FILE")"

echo "Configuration du système..."
hostnamectl set-hostname "$system_hostname"
timedatectl set-timezone "$system_timezone"
echo "LANG=$system_locale" > /etc/default/locale
sed -i "s/^# *${system_locale}/${system_locale}/" /etc/locale.gen && locale-gen
sed -i "s/XKBLAYOUT=.*/XKBLAYOUT=\"$system_keyboard_layout\"/" /etc/default/keyboard
raspi-config nonint do_wifi_country "$system_wifi_country"

echo "Nettoyage des services par défaut..."
rm -f /etc/xdg/autostart/piwiz.desktop
touch /etc/cloud/cloud-init.disabled
systemctl disable --now userconfig.service cloud-init.service systemd-networkd-wait-online.service NetworkManager-wait-online.service 2>/dev/null || true

echo "Mise à jour et installation des paquets..."
apt-get update && apt-get upgrade -y
apt-get install -y --no-install-recommends \
    network-manager avahi-daemon openssh-server rfkill iw \
    $(echo "$packages_install" | sed 's/- //g') \
    && apt-get remove -y --purge $(echo "$packages_remove" | sed 's/- //g')

echo "Configuration de l'utilisateur '$system_default_user'..."
if id "pi" &>/dev/null; then
    usermod -l "$system_default_user" pi
    usermod -d "/home/$system_default_user" -m "$system_default_user"
    groupmod -n "$system_default_user" pi
else
    useradd -m -s /bin/bash -G sudo,netdev "$system_default_user"
fi
echo "$system_default_user:$system_default_password" | chpasswd
if [ "$system_autologin" = "true" ]; then
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin $system_default_user --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/autologin.conf
fi
echo "$system_default_user ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/010_${system_default_user}-nopasswd"
sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

echo "Copie du fichier de configuration..."
mkdir -p /etc/runtipios && cp "$CONFIG_FILE" /etc/runtipios/config.yml

echo "Création du message de bienvenue (MOTD)..."
cat > /etc/motd << 'MOTDEOF'
\033

---

### 6. `scripts/install-wifi-connect.sh` (Installation du portail WiFi)

