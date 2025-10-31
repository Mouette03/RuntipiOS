#!/bin/bash
# RuntipiOS Image Builder - Version de débogage final
set -euo pipefail

# --- Fonctions de log ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

BUILD_DIR="/build"
CONFIG_FILE="${BUILD_DIR}/config.yml"

log_info "Chargement de la configuration depuis config.yml..."

# ============================================================================
#               --- BLOC DE DÉBOGAGE ULTIME ---
# ============================================================================
log_warning "--- DÉBUT DE LA VÉRIFICATION DU FICHIER DE CONFIGURATION ---"

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Le fichier de configuration n'a PAS été trouvé à l'emplacement attendu: ${CONFIG_FILE}"
    log_info "Contenu du répertoire /build/ pour vérifier si les fichiers sont bien montés :"
    ls -laR /build/
    exit 10 # Code d'erreur spécifique "Fichier non trouvé"
fi

log_success "Fichier de configuration trouvé : ${CONFIG_FILE}"
log_info "Permissions du fichier :"
ls -l "$CONFIG_FILE"

if [ ! -s "$CONFIG_FILE" ]; then
    log_error "Le fichier de configuration a été trouvé, mais il est VIDE !"
    log_info "Cela indique probablement un problème avec le montage du volume dans la commande 'docker run'."
    exit 11 # Code d'erreur spécifique "Fichier vide"
fi

log_success "Le fichier n'est pas vide. Contenu des 20 premières lignes :"
head -n 20 "$CONFIG_FILE"

log_info "Tentative de validation de la syntaxe YAML avec 'yq'..."
if yq . "$CONFIG_FILE" > /dev/null; then
    log_success "La syntaxe YAML du fichier de configuration est VALIDE."
else
    log_error "yq a détecté une ERREUR DE SYNTAXE dans le fichier config.yml !"
    log_error "Le build ne peut pas continuer."
    exit 12 # Code d'erreur spécifique "Syntaxe invalide"
fi
log_warning "--- FIN DE LA VÉRIFICATION ---"
# ============================================================================

# --- Exécution normale du script ---
# Si le script arrive jusqu'ici, c'est que le fichier est correct.
# L'erreur vient donc de la commande `eval` elle-même.

eval "$(yq -o=shell "$CONFIG_FILE")"

# Le reste du script `build-image.sh` continue ici...
# (Pas besoin de le recopier, le début est la seule chose qui compte pour ce débogage)

# ... (Copiez le reste de votre script build-image.sh à partir d'ici)
# Exemple:
# BASE_IMAGE_XZ="${WORK_DIR}/raspios-base.img.xz"
# ...
