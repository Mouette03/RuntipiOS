# RuntipiOS

> A custom Raspberry Pi OS image (Trixie Lite 64-bit) with a first-boot web configuration portal and automatic [Runtipi](https://runtipi.io) installation — no keyboard, no monitor, no hassle.

---

## 🇬🇧 English

### What is RuntipiOS?

RuntipiOS is a ready-to-flash Raspberry Pi OS image (Trixie Lite 64-bit) that guides you through initial setup via a local web portal on first boot — no keyboard, no monitor required.

Once configured, it automatically installs **Runtipi**, a self-hosted app store for your Raspberry Pi (Plex, Nextcloud, Home Assistant, and 200+ more apps).

### Features

- **Zero-touch setup** — connect to the `TipiSetup` WiFi hotspot, open a browser, done
- **Web configuration portal** — hostname, SSH user/password, timezone, locale, static IP, WiFi
- **Multilingual** — English, French, German, Spanish (auto-detected, switchable at any time)
- **Automatic Runtipi installation** — Docker included, starts on every reboot
- **mDNS support** — access via `tipisetup.local:8080` without typing an IP address
- **Ethernet & WiFi** — works with both; WiFi hotspot as fallback
- **Optional Cockpit** — web-based system management interface (port 9090), enable via checkbox during setup

### First Boot Flow

```
Flash image → Power on → Connect to "TipiSetup" WiFi (no password)
  → Open http://tipisetup.local:8080  (or http://10.42.0.1:8080)
  → Fill in the form → Click "Apply and install Runtipi"
  → Watch the live log stream in your browser
  → Automatic reboot
  → Access Runtipi at http://<your-hostname>.local
    (e.g. http://runtipios.local or http://192.168.1.50)
```

**Installation order** (runs automatically after you click Apply):
1. System configuration — hostname, timezone, locale, user, SSH
2. Network — static IP and/or WiFi credentials
3. `apt update && apt upgrade` — requires internet; runs after WiFi is connected
4. Runtipi — Docker + Runtipi installer

> **Note:** If the Runtipi installer fails during first boot (network hiccup, timeout), a systemd service (`tipi-runtipi-retry.service`) retries it automatically on the next reboot. The retry script (`retry-runtipi.sh`) runs once, then disables itself.

### Requirements

- Raspberry Pi 4 or 5
- microSD card (16 GB minimum, 32 GB recommended)
- A device with a web browser (phone, laptop, tablet)

### Building the Image

The image is built with [pi-gen](https://github.com/RPi-Distro/pi-gen) (arm64 branch).

```bash
# Clone this repo alongside a pi-gen checkout
git clone https://github.com/<your-username>/RuntipiOS
cd RuntipiOS

# Build (requires Docker)
./build.sh

# Flash the resulting image to your microSD card
# The image is placed in deploy/
```

### Project Structure

```
stage-tipi/
└── 01-config/
    └── files/
        ├── app/
        │   ├── app.py              # Flask portal (port 8080)
        │   ├── setup.py            # System installation script (subprocess)
        │   ├── translations.py     # Shared i18n dictionary (EN/FR/DE/ES)
        │   ├── static/
        │   └── templates/
        │       ├── base.html
        │       ├── configure.html
        │       ├── progress.html
        │       └── wifi.html
        ├── retry-runtipi.sh        # Retries Runtipi install on next boot if first attempt failed
        ├── start.sh                # Startup: hostapd, dnsmasq, Flask
        ├── tipi-runtipi-retry.service  # systemd service for retry-runtipi.sh
        └── tipi-setup.service      # systemd service (first boot only)
```

### How It Works

| Component | Role |
|-----------|------|
| `hostapd` | Creates the `TipiSetup` WiFi hotspot (SSID, no password) |
| `dnsmasq` | DHCP + DNS for clients connected to the hotspot |
| `Flask` | Serves the configuration portal on port 8080 — access via `http://tipisetup.local:8080` or `http://10.42.0.1:8080` |
| `setup.py` | Subprocess: configures hostname, SSH, locale, network, then runs `apt upgrade` and the Runtipi installer |
| `avahi` | mDNS so `<hostname>.local` resolves on the LAN after reboot |
| `retry-runtipi.sh` | Retries the Runtipi installer on the next boot if it failed; self-disables after one successful run |
| `cockpit` | Optional web system management UI on port 9090 — installed at build time, disabled by default, enabled via the setup portal |

### Adding a Language

Edit `stage-tipi/01-config/files/app/translations.py`:

1. Copy the `"en"` block and rename it (e.g. `"it"`)
2. Translate all values
3. Add the language code to `LANG_LABELS` with its flag emoji and abbreviation

Templates and `setup.py` pick it up automatically — no other changes needed.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `http://tipisetup.local:8080` unreachable | mDNS not working on your device | Use `http://10.42.0.1:8080` instead |
| Installation log freezes mid-way or final message missing | Concurrent poll bug (old image) | Fixed in current build — polling is serialised, no manual action needed |
| Runtipi not running after reboot | First-boot installer failed | Connect to LAN, wait for the retry service, or SSH in and run `retry-runtipi.sh` manually |
| Can't SSH in | SSH port or key misconfigured | Re-flash and redo setup; check the SSH port you entered |

### License

MIT

---

## 🇫🇷 Français

### Qu'est-ce que RuntipiOS ?

RuntipiOS est une image Raspberry Pi OS prête à flasher (Trixie Lite 64-bit) qui guide la configuration initiale via un portail web local au premier démarrage — sans clavier, sans écran.

Une fois configuré, il installe automatiquement **Runtipi**, un store d'applications auto-hébergé pour Raspberry Pi (Plex, Nextcloud, Home Assistant, et 200+ applications).

### Fonctionnalités

- **Configuration sans écran** — connectez-vous au hotspot WiFi `TipiSetup`, ouvrez un navigateur, c'est tout
- **Portail de configuration web** — hostname, utilisateur SSH, mot de passe, fuseau horaire, locale, IP statique, WiFi
- **Multilingue** — anglais, français, allemand, espagnol (changeable à tout moment)
- **Installation automatique de Runtipi** — Docker inclus, démarre à chaque reboot
- **Support mDNS** — accès via `tipisetup.local:8080` sans saisir d'adresse IP
- **Ethernet & WiFi** — fonctionne avec les deux ; hotspot WiFi en solution de repli
- **Cockpit optionnel** — interface web de gestion système (port 9090), activable via une case à cocher lors de la configuration

### Déroulement au premier démarrage

```
Flasher l'image → Démarrer → Se connecter au WiFi "TipiSetup" (sans mot de passe)
  → Ouvrir http://tipisetup.local:8080  (ou http://10.42.0.1:8080)
  → Remplir le formulaire → Cliquer "Appliquer et installer Runtipi"
  → Suivre les logs en direct dans le navigateur
  → Redémarrage automatique
  → Accéder à Runtipi sur http://<votre-hostname>.local
    (ex : http://runtipios.local ou http://192.168.1.50)
```

**Ordre d'installation** (s'exécute automatiquement après avoir cliqué sur Appliquer) :
1. Configuration système — hostname, fuseau horaire, locale, utilisateur, SSH
2. Réseau — IP statique et/ou identifiants WiFi
3. `apt update && apt upgrade` — nécessite Internet ; s'exécute après la connexion WiFi
4. Runtipi — installateur Docker + Runtipi

> **Note :** Si l'installateur Runtipi échoue au premier démarrage (coupure réseau, timeout), un service systemd (`tipi-runtipi-retry.service`) le relance automatiquement au prochain démarrage. Le script de relance (`retry-runtipi.sh`) s'exécute une fois, puis se désactive.

### Matériel requis

- Raspberry Pi 4 ou 5
- Carte microSD (16 Go minimum, 32 Go recommandé)
- Un appareil avec un navigateur web (téléphone, ordinateur, tablette)

### Construction de l'image

L'image est construite avec [pi-gen](https://github.com/RPi-Distro/pi-gen) (branche arm64).

```bash
# Cloner ce dépôt à côté d'un checkout pi-gen
git clone https://github.com/<votre-nom>/RuntipiOS
cd RuntipiOS

# Construire (nécessite Docker)
./build.sh

# Flasher l'image résultante sur la carte microSD
# L'image se trouve dans deploy/
```

### Structure du projet

```
stage-tipi/
└── 01-config/
    └── files/
        ├── app/
        │   ├── app.py              # Portail Flask (port 8080)
        │   ├── setup.py            # Script d'installation système (subprocess)
        │   ├── translations.py     # Dictionnaire i18n partagé (EN/FR/DE/ES)
        │   ├── static/
        │   └── templates/
        │       ├── base.html
        │       ├── configure.html
        │       ├── progress.html
        │       └── wifi.html
        ├── retry-runtipi.sh        # Relance l'install Runtipi au prochain boot si échec
        ├── start.sh                # Démarrage : hostapd, dnsmasq, Flask
        ├── tipi-runtipi-retry.service  # Service systemd pour retry-runtipi.sh
        └── tipi-setup.service      # Service systemd (premier démarrage uniquement)
```

### Fonctionnement

| Composant | Rôle |
|-----------|------|
| `hostapd` | Crée le hotspot WiFi `TipiSetup` (SSID, sans mot de passe) |
| `dnsmasq` | DHCP + DNS pour les clients connectés au hotspot |
| `Flask` | Sert le portail de configuration sur le port 8080 — accès via `http://tipisetup.local:8080` ou `http://10.42.0.1:8080` |
| `setup.py` | Subprocess : configure hostname, SSH, locale, réseau, puis lance `apt upgrade` et l'installateur Runtipi |
| `avahi` | mDNS pour que `<hostname>.local` soit résolu sur le réseau local après redémarrage |
| `retry-runtipi.sh` | Relance l'installateur Runtipi au prochain boot en cas d'échec ; se désactive après une réussite |
| `cockpit` | Interface web de gestion système optionnelle sur le port 9090 — installée au build, désactivée par défaut, activable via le portail de configuration |

### Ajouter une langue

Éditez `stage-tipi/01-config/files/app/translations.py` :

1. Copiez le bloc `"en"` et renommez-le (ex : `"it"`)
2. Traduisez toutes les valeurs
3. Ajoutez le code de langue dans `LANG_LABELS` avec son emoji et son sigle

Les templates et `setup.py` l'utilisent automatiquement — aucune autre modification nécessaire.

### Dépannage

| Symptôme | Cause probable | Solution |
|----------|---------------|----------|
| `http://tipisetup.local:8080` inaccessible | mDNS ne fonctionne pas sur l'appareil | Utiliser `http://10.42.0.1:8080` à la place |
| Les logs se figent en cours d'installation ou le message final n'apparaît pas | Bug de polling concurrent (ancienne image) | Corrigé dans la version actuelle — le polling est sérialisé, aucune action manuelle nécessaire |
| Runtipi absent après le redémarrage | L'installateur a échoué au premier boot | Se connecter au réseau local, attendre le service de relance, ou se connecter en SSH et lancer `retry-runtipi.sh` manuellement |
| Impossible de se connecter en SSH | Port ou clé SSH mal configurés | Reflasher et recommencer la configuration ; vérifier le port SSH saisi |

### Licence

MIT


