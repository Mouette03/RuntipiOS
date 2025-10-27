# RuntipiOS

![RuntipiOS Logo](https://img.shields.io/badge/RuntipiOS-Ready-blue?style=for-the-badge)
![License](https://img.shields.io/github/license/votre-username/runtipios?style=for-the-badge)
![Latest Release](https://img.shields.io/github/v/release/votre-username/runtipios?style=for-the-badge)

**RuntipiOS** est un système d'exploitation Raspberry Pi optimisé qui installe automatiquement [Runtipi](https://runtipi.io/) avec une configuration WiFi simplifiée via smartphone grâce à Balena WiFi-Connect.

## 🌟 Caractéristiques

- ✅ **Installation automatique** de Runtipi au premier démarrage
- 📱 **Configuration WiFi sans écran** via portail captif accessible depuis smartphone
- 🔌 **Support Ethernet** avec détection automatique
- 🎨 **Page de statut web** pour suivre l'installation
- 🔒 **Sécurisé** avec SSH activé et utilisateur personnalisable
- 🐳 **Docker pré-installé** et configuré
- 📡 **Avahi/mDNS** pour accès via `runtipios.local`
- ⚙️ **Entièrement personnalisable** via fichier de configuration

## 🚀 Installation Rapide

### 1. Télécharger l'image

Rendez-vous dans les [Releases](https://github.com/votre-username/runtipios/releases) et téléchargez la dernière image `.img.xz`.

### 2. Flasher l'image

Utilisez [Raspberry Pi Imager](https://www.raspberrypi.com/software/) ou [Etcher](https://www.balena.io/etcher/):

1. Sélectionnez l'image téléchargée
2. Sélectionnez votre carte microSD (minimum 8 Go recommandé)
3. Flashez !

### 3. Premier démarrage

1. **Insérez la carte SD** dans votre Raspberry Pi
2. **Branchez l'alimentation** (et optionnellement un câble Ethernet)
3. **Attendez 2-3 minutes** que le système démarre

### 4. Configuration WiFi (si pas d'Ethernet)

1. **Recherchez le réseau WiFi** `RuntipiOS-Setup` sur votre smartphone
2. **Connectez-vous** (réseau ouvert par défaut)
3. **Le portail captif s'ouvre automatiquement**
   - Sinon, ouvrez un navigateur et allez sur `http://192.168.4.1`
4. **Sélectionnez votre réseau WiFi** et entrez le mot de passe
5. **Validez** la configuration

### 5. Accéder à Runtipi

Après 10-15 minutes (temps d'installation de Runtipi), accédez à:

- **Via mDNS**: `http://runtipios.local`
- **Via IP**: `http://<adresse-ip-de-votre-pi>`
- **Page de statut**: `http://runtipios.local:8080`

## 🔑 Identifiants par Défaut

- **Utilisateur**: `runtipi`
- **Mot de passe**: `runtipi`
- **SSH**: Activé sur le port 22

⚠️ **IMPORTANT**: Changez le mot de passe dès la première connexion !

```bash
ssh runtipi@runtipios.local
passwd
```

## ⚙️ Configuration Personnalisée

### Modifier les paramètres avant le build

1. **Clonez le repository**:
```bash
git clone https://github.com/votre-username/runtipios.git
cd runtipios
```

2. **Modifiez `config.yml`** selon vos besoins:

```yaml
# Version de Raspberry Pi OS
raspios:
  version: "2024-11-19"
  variant: "lite"
  arch: "arm64"

# Version de Runtipi
runtipi:
  version: "v3.8.0"
  auto_install: true

# Configuration WiFi-Connect
wifi_connect:
  ssid: "MonServeur-Setup"
  password: "motdepasse123"

# Configuration système
system:
  hostname: "monserveur"
  timezone: "Europe/Paris"
  default_user: "admin"
  default_password: "monpassword"
```

3. **Lancez le build localement** (voir section Build)

## 🛠️ Build depuis les Sources

### Prérequis

- Docker installé
- Au moins 20 Go d'espace disque libre
- Connexion Internet stable

### Build local

```bash
# Cloner le repository
git clone https://github.com/votre-username/runtipios.git
cd runtipios

# Modifier config.yml si nécessaire
nano config.yml

# Construire l'image Docker builder
docker build -t runtipios-builder .

# Lancer le build de l'image Raspberry Pi
mkdir -p output
docker run --rm --privileged \
  -v $(pwd)/config.yml:/build/config.yml:ro \
  -v $(pwd)/output:/build/output \
  -v $(pwd)/scripts:/build/scripts:ro \
  runtipios-builder \
  /bin/bash -c "/build/scripts/build-image.sh"

# L'image finale sera dans le dossier output/
ls -lh output/
```

### Build via GitHub Actions

1. **Forkez le repository**
2. **Modifiez `config.yml`** si nécessaire
3. **Poussez un tag** pour déclencher le build:

```bash
git tag v1.0.0
git push origin v1.0.0
```

4. **L'image sera automatiquement** disponible dans les Releases après environ 30-45 minutes

Ou lancez manuellement via l'onglet "Actions" > "Build and Release RuntipiOS" > "Run workflow"

## 📦 Structure du Projet

```
runtipios/
├── .github/
│   └── workflows/
│       └── build-release.yml    # Workflow GitHub Actions
├── scripts/
│   ├── build-image.sh           # Script principal de build
│   ├── customize-os.sh          # Customisation du système
│   ├── install-wifi-connect.sh  # Installation de WiFi-Connect
│   ├── install-runtipi.sh       # Installation de Runtipi
│   └── setup-services.sh        # Configuration des services
├── config.yml                   # Configuration principale
├── Dockerfile                   # Image Docker pour le build
├── README.md                    # Ce fichier
├── LICENSE                      # Licence MIT
└── .gitignore                   # Fichiers à ignorer
```

## 🔧 Personnalisation Avancée

### Modifier la page de statut web

La page de statut est générée dans `scripts/customize-os.sh`. Vous pouvez la personnaliser en modifiant le HTML/CSS/JavaScript.

### Ajouter des packages

Dans `config.yml`, section `packages`:

```yaml
packages:
  install:
    - mon-package
    - autre-package
  remove:
    - package-inutile
```

### Changer le logo Runtipi au démarrage

Pour afficher le logo Runtipi au démarrage de la page de statut, modifiez la section dans `customize-os.sh`:

```javascript
// Ajouter une image du logo
<div class="logo">
    <img src="https://runtipi.io/img/logo.png" alt="Runtipi" style="max-width: 200px;">
</div>
```

### Services supplémentaires

Ajoutez vos propres services systemd dans `scripts/setup-services.sh`.

## 🐛 Dépannage

### Le portail WiFi ne s'affiche pas

1. Vérifiez que vous êtes bien connecté au réseau `RuntipiOS-Setup`
2. Ouvrez manuellement un navigateur et allez sur `http://192.168.4.1`
3. Sur Android, désactivez temporairement les données mobiles

### Runtipi ne s'installe pas

1. Vérifiez la connexion Internet: `ping google.com`
2. Consultez les logs: `sudo journalctl -u runtipi-installer.service`
3. Relancez l'installation: `sudo systemctl start runtipi-installer.service`

### Impossible d'accéder via .local

1. Vérifiez qu'Avahi fonctionne: `sudo systemctl status avahi-daemon`
2. Sur Windows, installez [Bonjour Print Services](https://support.apple.com/kb/DL999)
3. Utilisez l'adresse IP directement: `ip addr show`

### SSH refuse la connexion

1. Vérifiez que SSH est actif: `sudo systemctl status ssh`
2. Vérifiez l'utilisateur et le mot de passe par défaut
3. Consultez les logs: `sudo journalctl -u ssh`

## 📊 Logs et Monitoring

### Voir l'installation de Runtipi en temps réel

```bash
# Via SSH
sudo tail -f /var/log/runtipi-install.log

# Ou avec systemd
sudo journalctl -u runtipi-installer.service -f
```

### Statut des services

```bash
# WiFi-Connect
sudo systemctl status wifi-connect

# Runtipi installer
sudo systemctl status runtipi-installer

# Docker
sudo systemctl status docker

# Avahi
sudo systemctl status avahi-daemon
```

## 🤝 Contribution

Les contributions sont les bienvenues !

1. Forkez le projet
2. Créez une branche (`git checkout -b feature/ma-fonctionnalite`)
3. Committez vos changements (`git commit -am 'Ajout de ma fonctionnalité'`)
4. Poussez vers la branche (`git push origin feature/ma-fonctionnalite`)
5. Ouvrez une Pull Request

## 📝 Changelog

Voir [RELEASES](https://github.com/votre-username/runtipios/releases) pour l'historique des versions.

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

- [Runtipi](https://runtipi.io/) - Le serveur personnel
- [Balena WiFi-Connect](https://github.com/balena-os/wifi-connect) - Portail captif WiFi
- [Raspberry Pi Foundation](https://www.raspberrypi.org/) - Raspberry Pi OS
- Tous les contributeurs du projet

## 📧 Support

- 🐛 [Issues](https://github.com/votre-username/runtipios/issues)
- 💬 [Discussions](https://github.com/votre-username/runtipios/discussions)
- 📖 [Documentation Runtipi](https://runtipi.io/docs)

---

Fait avec ❤️ pour la communauté Runtipi et Raspberry Pi
