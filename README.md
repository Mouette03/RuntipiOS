# TipiOS

> A custom Raspberry Pi OS image (Trixie Lite 64-bit) with a first-boot web configuration portal and automatic [runTipi](https://runtipi.io) installation — no keyboard, no monitor, no hassle.

---

## 🇬🇧 English

### What is TipiOS?

TipiOS is a ready-to-flash Raspberry Pi OS image (Trixie Lite 64-bit) that guides you through initial setup via a local web portal on first boot — no keyboard, no monitor required.

Once configured, it automatically installs **runTipi**, a self-hosted app store for your Raspberry Pi (Plex, Nextcloud, Home Assistant, and 200+ more apps).

### Features

- **Zero-touch setup** — connect to the `TipiSetup` WiFi hotspot, open a browser, done
- **Web configuration portal** — hostname, SSH user/password, timezone, locale, static IP, WiFi
- **Multilingual** — English, French, German, Spanish (auto-detected, switchable at any time)
- **Automatic runTipi installation** — Docker included, starts on every reboot
- **Resilient portal** — a Python watchdog keeps the web portal accessible even while Docker is installing and flushing firewall rules
- **mDNS support** — access via `tipisetup.local` without typing an IP address
- **Ethernet & WiFi** — works with both; WiFi hotspot as fallback

### First Boot Flow

```
Flash image → Power on → Connect to "TipiSetup" WiFi (no password)
  → Open http://tipisetup.local  (or http://10.42.0.1)
  → Fill in the form → Click "Apply and install runTipi"
  → Watch the live log stream in your browser
  → Automatic reboot
  → Access runTipi at http://<your-hostname>.local
    (e.g. http://tipios.local or http://192.168.1.50)
```

**Installation order** (runs automatically after you click Apply):
1. System configuration — hostname, timezone, locale, user, SSH
2. Network — static IP and/or WiFi credentials
3. `apt update && apt upgrade` — requires internet; runs after WiFi is connected
4. runTipi — Docker + runTipi installer

> **Note:** If the runTipi installer fails during first boot (network hiccup, timeout), a systemd service (`tipi-runtipi-retry.service`) retries it automatically on the next reboot. The retry script (`retry-runtipi.sh`) runs once, then disables itself.

### Requirements

- Raspberry Pi 4 or 5
- microSD card (16 GB minimum, 32 GB recommended)
- A device with a web browser (phone, laptop, tablet)

### Building the Image

The image is built with [pi-gen](https://github.com/RPi-Distro/pi-gen) (arm64 branch).

```bash
# Clone this repo alongside a pi-gen checkout
git clone https://github.com/<your-username>/tipiOS
cd tipiOS

# Build (requires Docker)
./build.sh

# Flash the resulting image to your microSD card
# The image is placed in deploy/
```

> **Kernel note (Raspberry Pi 5):** The RPi 5 kernel (`6.x rpi-2712`) does not include the `ip_tables` module, so `iptables-legacy` is not available. TipiOS uses **nftables exclusively** for firewall and NAT rules. This is transparent to the user.

### Project Structure

```
stage-tipi/
└── 01-config/
    └── files/
        ├── app/
        │   ├── app.py              # Flask portal (port 8080) + nftables watchdog
        │   ├── setup.py            # System installation script (subprocess)
        │   ├── translations.py     # Shared i18n dictionary (EN/FR/DE/ES)
        │   ├── static/
        │   └── templates/
        │       ├── base.html
        │       ├── configure.html
        │       ├── progress.html
        │       └── wifi.html
        ├── retry-runtipi.sh        # Retries runTipi install on next boot if first attempt failed
        ├── start.sh                # Startup: hostapd, dnsmasq, nftables, Flask
        ├── tipi-runtipi-retry.service  # systemd service for retry-runtipi.sh
        └── tipi-setup.service      # systemd service (first boot only)
```

### How It Works

| Component | Role |
|-----------|------|
| `hostapd` | Creates the `TipiSetup` WiFi hotspot (SSID, no password) |
| `dnsmasq` | DHCP + DNS for clients connected to the hotspot |
| `nftables` | NAT rule redirecting port 80 → 8080 at priority −150, so the portal is reachable without a port number |
| Python watchdog | Background thread in `app.py` — re-applies the nftables rule every 2 s while Docker is installing (Docker resets firewall rules at startup) |
| `Flask` | Serves the configuration portal on port 8080 |
| `setup.py` | Subprocess: configures hostname, SSH, locale, network, then runs `apt upgrade` and the runTipi installer |
| `avahi` | mDNS so `<hostname>.local` resolves on the LAN after reboot |
| `retry-runtipi.sh` | Retries the runTipi installer on the next boot if it failed; self-disables after one successful run |

#### Why priority −150 for nftables?

Docker registers its own NAT chain at nftables priority −100. If our rule were at the same priority and Docker flushed and rewrote the table, our rule could lose the tie. By using −150 (lower number = higher precedence), the portal redirect always wins, even after Docker rewrites the firewall.

### Adding a Language

Edit `stage-tipi/01-config/files/app/translations.py`:

1. Copy the `"en"` block and rename it (e.g. `"it"`)
2. Translate all values
3. Add the language code to `LANG_LABELS` with its flag emoji and abbreviation

Templates and `setup.py` pick it up automatically — no other changes needed.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `http://tipisetup.local` unreachable | mDNS not working on your device | Use `http://10.42.0.1` instead |
| Portal loads but installation log stops updating | Browser lost the SSE connection | Refresh the page — the log stream reconnects automatically |
| runTipi not running after reboot | First-boot installer failed | Connect to LAN, wait for the retry service, or SSH in and run `retry-runtipi.sh` manually |
| `nft list ruleset` shows no `tipi_nat` table | Flask / watchdog not running | Check `journalctl -u tipi-setup` |
| Can't SSH in | SSH port or key misconfigured | Re-flash and redo setup; check the SSH port you entered |

### License

MIT

---

## 🇫🇷 Français

### Qu'est-ce que TipiOS ?

TipiOS est une image Raspberry Pi OS prête à flasher (Trixie Lite 64-bit) qui guide la configuration initiale via un portail web local au premier démarrage — sans clavier, sans écran.

Une fois configuré, il installe automatiquement **runTipi**, un store d'applications auto-hébergé pour Raspberry Pi (Plex, Nextcloud, Home Assistant, et 200+ applications).

### Fonctionnalités

- **Configuration sans écran** — connectez-vous au hotspot WiFi `TipiSetup`, ouvrez un navigateur, c'est tout
- **Portail de configuration web** — hostname, utilisateur SSH, mot de passe, fuseau horaire, locale, IP statique, WiFi
- **Multilingue** — anglais, français, allemand, espagnol (changeable à tout moment)
- **Installation automatique de runTipi** — Docker inclus, démarre à chaque reboot
- **Portail résilient** — un watchdog Python maintient le portail web accessible même pendant que Docker s'installe et réinitialise les règles pare-feu
- **Support mDNS** — accès via `tipisetup.local` sans saisir d'adresse IP
- **Ethernet & WiFi** — fonctionne avec les deux ; hotspot WiFi en solution de repli

### Déroulement au premier démarrage

```
Flasher l'image → Démarrer → Se connecter au WiFi "TipiSetup" (sans mot de passe)
  → Ouvrir http://tipisetup.local  (ou http://10.42.0.1)
  → Remplir le formulaire → Cliquer "Appliquer et installer runTipi"
  → Suivre les logs en direct dans le navigateur
  → Redémarrage automatique
  → Accéder à runTipi sur http://<votre-hostname>.local
    (ex : http://tipios.local ou http://192.168.1.50)
```

**Ordre d'installation** (s'exécute automatiquement après avoir cliqué sur Appliquer) :
1. Configuration système — hostname, fuseau horaire, locale, utilisateur, SSH
2. Réseau — IP statique et/ou identifiants WiFi
3. `apt update && apt upgrade` — nécessite Internet ; s'exécute après la connexion WiFi
4. runTipi — installateur Docker + runTipi

> **Note :** Si l'installateur runTipi échoue au premier démarrage (coupure réseau, timeout), un service systemd (`tipi-runtipi-retry.service`) le relance automatiquement au prochain démarrage. Le script de relance (`retry-runtipi.sh`) s'exécute une fois, puis se désactive.

### Matériel requis

- Raspberry Pi 4 ou 5
- Carte microSD (16 Go minimum, 32 Go recommandé)
- Un appareil avec un navigateur web (téléphone, ordinateur, tablette)

### Construction de l'image

L'image est construite avec [pi-gen](https://github.com/RPi-Distro/pi-gen) (branche arm64).

```bash
# Cloner ce dépôt à côté d'un checkout pi-gen
git clone https://github.com/<votre-nom>/tipiOS
cd tipiOS

# Construire (nécessite Docker)
./build.sh

# Flasher l'image résultante sur la carte microSD
# L'image se trouve dans deploy/
```

> **Note kernel (Raspberry Pi 5) :** Le kernel du RPi 5 (`6.x rpi-2712`) n'inclut pas le module `ip_tables`, donc `iptables-legacy` n'est pas disponible. TipiOS utilise **nftables exclusivement** pour les règles pare-feu et NAT. Cela est transparent pour l'utilisateur.

### Structure du projet

```
stage-tipi/
└── 01-config/
    └── files/
        ├── app/
        │   ├── app.py              # Portail Flask (port 8080) + watchdog nftables
        │   ├── setup.py            # Script d'installation système (subprocess)
        │   ├── translations.py     # Dictionnaire i18n partagé (EN/FR/DE/ES)
        │   ├── static/
        │   └── templates/
        │       ├── base.html
        │       ├── configure.html
        │       ├── progress.html
        │       └── wifi.html
        ├── retry-runtipi.sh        # Relance l'install runTipi au prochain boot si échec
        ├── start.sh                # Démarrage : hostapd, dnsmasq, nftables, Flask
        ├── tipi-runtipi-retry.service  # Service systemd pour retry-runtipi.sh
        └── tipi-setup.service      # Service systemd (premier démarrage uniquement)
```

### Fonctionnement

| Composant | Rôle |
|-----------|------|
| `hostapd` | Crée le hotspot WiFi `TipiSetup` (SSID, sans mot de passe) |
| `dnsmasq` | DHCP + DNS pour les clients connectés au hotspot |
| `nftables` | Règle NAT redirigeant le port 80 → 8080 à priorité −150, pour accéder au portail sans numéro de port |
| Watchdog Python | Thread de fond dans `app.py` — réapplique la règle nftables toutes les 2 s pendant l'installation Docker (Docker réinitialise les règles au démarrage) |
| `Flask` | Sert le portail de configuration sur le port 8080 |
| `setup.py` | Subprocess : configure hostname, SSH, locale, réseau, puis lance `apt upgrade` et l'installateur runTipi |
| `avahi` | mDNS pour que `<hostname>.local` soit résolu sur le réseau local après redémarrage |
| `retry-runtipi.sh` | Relance l'installateur runTipi au prochain boot en cas d'échec ; se désactive après une réussite |

#### Pourquoi la priorité −150 pour nftables ?

Docker enregistre sa propre chaîne NAT à la priorité nftables −100. Si notre règle était à la même priorité et que Docker vidait et réécrivait la table, notre règle pourrait perdre la priorité. En utilisant −150 (nombre plus bas = précédence plus haute), la redirection du portail l'emporte toujours, même après que Docker réécrit le pare-feu.

### Ajouter une langue

Éditez `stage-tipi/01-config/files/app/translations.py` :

1. Copiez le bloc `"en"` et renommez-le (ex : `"it"`)
2. Traduisez toutes les valeurs
3. Ajoutez le code de langue dans `LANG_LABELS` avec son emoji et son sigle

Les templates et `setup.py` l'utilisent automatiquement — aucune autre modification nécessaire.

### Dépannage

| Symptôme | Cause probable | Solution |
|----------|---------------|----------|
| `http://tipisetup.local` inaccessible | mDNS ne fonctionne pas sur l'appareil | Utiliser `http://10.42.0.1` à la place |
| Le portail charge mais les logs s'arrêtent | Le navigateur a perdu la connexion SSE | Rafraîchir la page — le flux se reconnecte automatiquement |
| runTipi absent après le redémarrage | L'installateur a échoué au premier boot | Se connecter au réseau local, attendre le service de relance, ou se connecter en SSH et lancer `retry-runtipi.sh` manuellement |
| `nft list ruleset` ne montre pas de table `tipi_nat` | Flask / watchdog non démarrés | Vérifier `journalctl -u tipi-setup` |
| Impossible de se connecter en SSH | Port ou clé SSH mal configurés | Reflasher et recommencer la configuration ; vérifier le port SSH saisi |

### Licence

MIT


