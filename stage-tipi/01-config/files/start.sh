#!/bin/bash
# TipiOS — Script de démarrage du portail de configuration
# Lancé par systemd au premier démarrage uniquement.
# Utilise hostapd directement (country_code=US) + dnsmasq pour DHCP.
# Ref : même approche que RaspAP — seule méthode fiable sur brcmfmac (RPi 4/5).

HOTSPOT_SSID="TipiSetup"
HOTSPOT_IP="10.42.0.1"
DNSMASQ_PID="/run/tipi-dnsmasq.pid"
HOSTAPD_PID="/run/tipi-hostapd.pid"
HOSTAPD_CONF="/etc/hostapd/tipi-hostapd.conf"

log() { echo "[tipi-setup] $*"; }

log "=== Démarrage tipi-setup $(date) ==="

# ------------------------------------------------------------------ #
#  1. Débloquer le WiFi                                               #
# ------------------------------------------------------------------ #
rfkill unblock wifi 2>/dev/null || true
rfkill unblock all  2>/dev/null || true
log "rfkill unblock effectué"

# ------------------------------------------------------------------ #
#  2. Attendre l'interface wlan0 (max 30s)                            #
# ------------------------------------------------------------------ #
log "Attente interface wlan0..."
WLAN_OK=0
for i in $(seq 1 30); do
    ip link show wlan0 &>/dev/null && WLAN_OK=1 && break
    sleep 1
done

if [ "$WLAN_OK" = "0" ]; then
    log "ERREUR : wlan0 absente après 30s — hotspot impossible"
    ip link 2>&1 | head -10 || true
fi

# ------------------------------------------------------------------ #
#  3. Hotspot via hostapd (country_code natif dans la config)         #
# ------------------------------------------------------------------ #
hotspot_active() {
    ip -4 addr show wlan0 2>/dev/null | grep -q "inet 10\.42\."
}

if hotspot_active; then
    log "Hotspot '${HOTSPOT_SSID}' déjà actif — skip création"
elif [ "$WLAN_OK" = "1" ]; then
    log "Création du hotspot avec hostapd..."

    # Sortir wlan0 de la gestion NetworkManager pour qu'hostapd puisse s'en emparer
    nmcli dev set wlan0 managed no 2>/dev/null || true
    sleep 1

    # Éteindre/rallumer wlan0 pour sortir de tout état précédent
    ip link set wlan0 down  2>/dev/null || true
    sleep 1
    ip link set wlan0 up    2>/dev/null || true

    # Assigner l'IP du point d'accès
    ip addr flush dev wlan0 2>/dev/null || true
    ip addr add "${HOTSPOT_IP}/24" dev wlan0

    # Lancer hostapd en daemon
    if hostapd -B -P "${HOSTAPD_PID}" "${HOSTAPD_CONF}"; then
        log "hostapd OK — SSID '${HOTSPOT_SSID}' en broadcast sur canal 6"
    else
        log "ERREUR hostapd (code $?) — diagnostic :"
        iw dev wlan0 info   2>&1 || true
        iw reg get          2>&1 | head -10 || true
        rfkill list         2>&1 || true
    fi

    # Lancer dnsmasq pour le DHCP sur wlan0
    dnsmasq \
        --interface=wlan0 \
        --bind-interfaces \
        --except-interface=lo \
        --dhcp-range=10.42.0.100,10.42.0.200,12h \
        --dhcp-option=3,"${HOTSPOT_IP}" \
        --dhcp-option=6,"${HOTSPOT_IP}" \
        --no-resolv \
        --no-poll \
        --pid-file="${DNSMASQ_PID}" 2>&1 | while read -r l; do log "dnsmasq: $l"; done &

    # Attendre que le AP soit visible
    sleep 3
    log "État radio wlan0 :"
    iw dev wlan0 info 2>&1 || true
    log "Domaine réglementaire :"
    iw reg get 2>&1 | head -5 || true
    log "Hotspot '${HOTSPOT_SSID}' — IP RPi : ${HOTSPOT_IP}"
fi

# ------------------------------------------------------------------ #
#  4. Redirection nftables 80 → 8080 (portail captif + accès direct)  #
# ------------------------------------------------------------------ #
nft add table ip tipi_nat 2>/dev/null || true
nft add chain ip tipi_nat prerouting '{ type nat hook prerouting priority -150; }' 2>/dev/null || true
nft add rule ip tipi_nat prerouting iif wlan0 tcp dport 80 redirect to :8080 2>/dev/null || true
nft add rule ip tipi_nat prerouting iif eth0  tcp dport 80 redirect to :8080 2>/dev/null || true
log "nftables: redirection port 80 → 8080 activée (watchdog Python actif)"

# ------------------------------------------------------------------ #
#  5. Lancement du portail web Flask (port 8080)                      #
# ------------------------------------------------------------------ #
log "Démarrage du portail de configuration (port 8080)..."
python3 /opt/tipi-setup/app.py
EXIT_CODE=$?
log "Flask terminé avec code $EXIT_CODE"
exit $EXIT_CODE
