# 🚀 Script de Création Rapide du Projet RuntipiOS

Ce document contient toutes les commandes pour créer rapidement la structure complète du projet.

## Étape 1: Créer le Repository GitHub

```bash
# Créer un nouveau repository sur GitHub (via interface web)
# Puis clonez-le localement

git clone https://github.com/VOTRE-USERNAME/runtipios.git
cd runtipios
```

## Étape 2: Créer la Structure des Dossiers

```bash
# Créer tous les dossiers nécessaires
mkdir -p .github/workflows
mkdir -p scripts

echo "✅ Structure de dossiers créée"
```

## Étape 3: Récupérer Tous les Fichiers

Copiez le contenu des fichiers suivants depuis les artifacts générés:

### 📄 Fichiers Racine

1. **`Dockerfile`** → [Voir artifact 145]
2. **`config.yml`** → [Voir artifact 146]
3. **`README.md`** → [Voir artifact 152]
4. **`.gitignore`** → [Voir artifact 153]
5. **`LICENSE`** → [Voir artifact 154]

### ⚙️ Scripts (dans le dossier `scripts/`)

6. **`scripts/build-image.sh`** → [Voir artifact 147]
7. **`scripts/install-runtipi.sh`** → [Voir artifact 148]
8. **`scripts/install-wifi-connect.sh`** → [Voir artifact 149]
9. **`scripts/customize-os.sh`** → [Voir artifact 150]
10. **`scripts/setup-services.sh`** → [Voir artifact 151]

### 🔄 Workflow GitHub Actions

11. **`.github/workflows/build-release.yml`** → [Voir artifact 155]

## Étape 4: Rendre les Scripts Exécutables

```bash
# Rendre tous les scripts exécutables
chmod +x scripts/*.sh

echo "✅ Scripts rendus exécutables"
```

## Étape 5: Personnaliser la Configuration

```bash
# Éditez config.yml selon vos besoins
nano config.yml

# Points importants à modifier:
# - system.default_password (CHANGER ABSOLUMENT!)
# - system.hostname
# - wifi_connect.ssid
# - runtipi.version
# - build.image_size
```

## Étape 6: Personnaliser le README

```bash
# Remplacez "votre-username" par votre nom d'utilisateur GitHub
sed -i 's/votre-username/VOTRE-USERNAME/g' README.md

# Ou éditez manuellement
nano README.md
```

## Étape 7: Commit Initial

```bash
# Ajouter tous les fichiers
git add .

# Commit initial
git commit -m "🎉 Initial commit: RuntipiOS project setup

- Raspberry Pi OS Lite base
- Automatic Runtipi installation
- Balena WiFi-Connect integration
- GitHub Actions automated build
- Configurable via config.yml"

# Pousser vers GitHub
git push origin main

echo "✅ Projet poussé vers GitHub"
```

## Étape 8: Créer une Release (Optionnel pour Test)

```bash
# Créer et pousser un tag pour déclencher le build
git tag v1.0.0-beta
git push origin v1.0.0-beta

echo "🚀 Build lancé ! Vérifiez l'onglet Actions sur GitHub"
```

## Vérification

Après avoir poussé le code, vérifiez que:

- [ ] Tous les fichiers sont présents sur GitHub
- [ ] L'onglet Actions affiche le workflow "Build and Release RuntipiOS"
- [ ] Si vous avez poussé un tag, le build démarre automatiquement

## Structure Finale Attendue

```
runtipios/
├── .github/
│   └── workflows/
│       └── build-release.yml
├── scripts/
│   ├── build-image.sh
│   ├── customize-os.sh
│   ├── install-wifi-connect.sh
│   ├── install-runtipi.sh
│   └── setup-services.sh
├── .gitignore
├── config.yml
├── Dockerfile
├── LICENSE
└── README.md
```

## 🎯 Commandes Utiles

### Lancer un Build Manuel

Via l'interface GitHub:
1. Aller dans Actions
2. Sélectionner "Build and Release RuntipiOS"
3. Cliquer "Run workflow"
4. Entrer une version (ex: 1.0.0-test)
5. Run workflow

### Créer une Release Officielle

```bash
# Version stable
git tag v1.0.0
git push origin v1.0.0

# Version beta
git tag v1.0.0-beta
git push origin v1.0.0-beta

# Version dev
git tag v1.0.0-dev
git push origin v1.0.0-dev
```

### Mettre à Jour la Configuration

```bash
# Modifier config.yml
nano config.yml

# Commit et push
git add config.yml
git commit -m "⚙️ Update configuration"
git push origin main

# Créer une nouvelle release
git tag v1.0.1
git push origin v1.0.1
```

### Voir les Logs du Build

1. GitHub → Actions
2. Cliquer sur le workflow en cours
3. Cliquer sur "build-rpi-image"
4. Voir "Build Raspberry Pi image"

### Tester Localement (Optionnel)

```bash
# Construire le builder
docker build -t runtipios-builder .

# Lancer le build
mkdir -p output
docker run --rm --privileged \
  -v $(pwd)/config.yml:/build/config.yml:ro \
  -v $(pwd)/output:/build/output \
  -v $(pwd)/scripts:/build/scripts:ro \
  runtipios-builder \
  /bin/bash -c "/build/scripts/build-image.sh"

# Vérifier l'image
ls -lh output/
```

## 🔧 Dépannage Rapide

### Erreur: "config.yml not found"

```bash
# Vérifier que le fichier existe
ls -la config.yml

# Vérifier le contenu
cat config.yml
```

### Erreur: "Permission denied" sur les scripts

```bash
# Rendre les scripts exécutables
chmod +x scripts/*.sh
git add scripts/
git commit -m "Fix: Make scripts executable"
git push
```

### Build GitHub Actions qui échoue

1. Vérifier les logs dans Actions
2. Vérifier config.yml (syntaxe YAML)
3. Vérifier que tous les scripts sont présents
4. Réduire `build.image_size` si "no space left"

## 📚 Prochaines Étapes

1. ✅ Créer la structure
2. ✅ Personnaliser config.yml
3. ✅ Pousser vers GitHub
4. ✅ Lancer le premier build
5. ⏳ Attendre 30-45 minutes
6. 📥 Télécharger l'image depuis Releases
7. 💾 Flasher sur carte SD
8. 🚀 Tester sur Raspberry Pi

## 🎉 Félicitations !

Vous avez maintenant un système RuntipiOS complet et fonctionnel !

Pour toute question, consultez:
- Le guide PDF complet
- Le README.md du projet
- Les issues GitHub
