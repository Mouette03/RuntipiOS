# 🌍 Guide d'Ajout de Langues au Portail Captif RuntipiOS

## Vue d'ensemble

Le portail captif WiFi-Connect de RuntipiOS est maintenant **entièrement multilingue** avec support intégré pour :

- 🇬🇧 **Anglais** (par défaut)
- 🇫🇷 **Français**
- ➕ **Facilement extensible** pour d'autres langues

## Nouvelles Fonctionnalités du Portail

### 📋 Informations Collectées

Le portail captif demande maintenant au **premier démarrage** :

1. **Utilisateur SSH** (nom d'utilisateur pour connexion SSH)
2. **Mot de passe SSH** (minimum 8 caractères, avec confirmation)
3. **SSID WiFi** (sélection dans la liste des réseaux détectés)
4. **Mot de passe WiFi** (optionnel pour réseaux ouverts)

### ✨ Caractéristiques de l'Interface

- **Interface en 3 étapes** :
  - Étape 1 : Configuration SSH
  - Étape 2 : Configuration WiFi  
  - Étape 3 : Résumé et confirmation

- **Sélecteur de langue** en haut de la page (🇬🇧 🇫🇷)
- **Scan automatique** des réseaux WiFi disponibles
- **Affichage/masquage** des mots de passe (bouton 👁️)
- **Validation en temps réel** des formulaires
- **Interface responsive** (mobile et desktop)
- **Design moderne** avec gradient et animations

## 🔧 Ajouter une Nouvelle Langue

### Méthode 1 : Modifier le fichier install-wifi-connect.sh

Éditer le fichier `scripts/install-wifi-connect.sh` et ajouter la langue dans l'objet `translations` du JavaScript :

```javascript
const translations = {
    en: { /* ... */ },
    fr: { /* ... */ },
    
    // AJOUTER ICI - Exemple pour l'espagnol
    es: {
        title: "Configuración RuntipiOS",
        subtitle: "Configuración inicial",
        'info-step1': "Configure sus credenciales SSH para acceso remoto seguro.",
        'label-ssh-user': "Usuario SSH",
        'label-ssh-pass': "Contraseña SSH",
        'hint-ssh-pass': "Mínimo 8 caracteres",
        'label-ssh-pass-confirm': "Confirmar contraseña",
        'btn-next-1': "Siguiente",
        'info-step2': "Seleccione su red WiFi e ingrese la contraseña.",
        'label-ssid': "Red WiFi (SSID)",
        'option-select': "Seleccionar una red...",
        'btn-scan': "🔄 Escanear redes",
        'label-wifi-pass': "Contraseña WiFi",
        'hint-wifi-pass': "Dejar vacío para redes abiertas",
        'btn-prev-2': "Anterior",
        'btn-next-2': "Siguiente",
        'info-step3': "Revise su configuración antes de aplicar.",
        'review-title': "Resumen de configuración",
        'review-ssh-user-label': "Usuario SSH:",
        'review-ssh-pass-label': "Contraseña SSH:",
        'review-ssid-label': "Red WiFi:",
        'review-wifi-pass-label': "Contraseña WiFi:",
        'btn-prev-3': "Anterior",
        'btn-apply': "Aplicar configuración",
        'applying-title': "Aplicando configuración...",
        'applying-text': "Esto puede tomar unos momentos. Por favor espere.",
        'error-passwords': "¡Las contraseñas no coinciden!",
        'error-password-length': "¡La contraseña debe tener al menos 8 caracteres!",
        'error-ssid': "¡Por favor seleccione una red WiFi!",
        'error-network': "Error de conexión. Verifique sus credenciales.",
        'success-title': "¡Configuración exitosa!",
        'success-text': "El sistema se está reiniciando. Puede acceder en:"
    }
};
```

### Méthode 2 : Fichier de traduction externe (recommandé pour production)

Pour faciliter la maintenance, créez un fichier `translations.js` séparé :

```javascript
// /usr/local/share/wifi-connect/ui/translations.js
const translations = {
    en: { /* ... */ },
    fr: { /* ... */ },
    es: { /* ... */ },
    de: { /* ... */ },
    it: { /* ... */ }
};
```

Puis dans `index.html`, ajoutez :
```html
<script src="translations.js"></script>
```

## 🎯 Clés de Traduction Complètes

Voici toutes les clés à traduire pour une nouvelle langue :

```javascript
{
    // Général
    title: "Titre de la page",
    subtitle: "Sous-titre",
    
    // Étape 1 - SSH
    'info-step1': "Info bulle étape 1",
    'label-ssh-user': "Label utilisateur SSH",
    'label-ssh-pass': "Label mot de passe SSH",
    'hint-ssh-pass': "Indication mot de passe",
    'label-ssh-pass-confirm': "Label confirmation",
    'btn-next-1': "Bouton suivant",
    
    // Étape 2 - WiFi
    'info-step2': "Info bulle étape 2",
    'label-ssid': "Label SSID",
    'option-select': "Option select dropdown",
    'btn-scan': "Bouton scan",
    'label-wifi-pass': "Label mot de passe WiFi",
    'hint-wifi-pass': "Indication mot de passe WiFi",
    'btn-prev-2': "Bouton précédent",
    'btn-next-2': "Bouton suivant",
    
    // Étape 3 - Résumé
    'info-step3': "Info bulle étape 3",
    'review-title': "Titre du résumé",
    'review-ssh-user-label': "Label utilisateur (résumé)",
    'review-ssh-pass-label': "Label mot de passe (résumé)",
    'review-ssid-label': "Label SSID (résumé)",
    'review-wifi-pass-label': "Label mot de passe WiFi (résumé)",
    'btn-prev-3': "Bouton précédent",
    'btn-apply': "Bouton appliquer",
    
    // Étape 4 - Application
    'applying-title': "Titre application en cours",
    'applying-text': "Texte application en cours",
    
    // Messages d'erreur
    'error-passwords': "Erreur mots de passe différents",
    'error-password-length': "Erreur longueur mot de passe",
    'error-ssid': "Erreur pas de SSID",
    'error-network': "Erreur de connexion réseau",
    
    // Messages de succès
    'success-title': "Titre succès",
    'success-text': "Texte succès"
}
```

## 🌐 Ajouter un Bouton de Langue

### Dans le HTML

Localisez la section `.language-selector` dans le fichier HTML :

```html
<div class="language-selector">
    <button class="lang-btn active" onclick="setLanguage('en')" data-lang="en">🇬🇧 English</button>
    <button class="lang-btn" onclick="setLanguage('fr')" data-lang="fr">🇫🇷 Français</button>
    
    <!-- AJOUTER ICI -->
    <button class="lang-btn" onclick="setLanguage('es')" data-lang="es">🇪🇸 Español</button>
    <button class="lang-btn" onclick="setLanguage('de')" data-lang="de">🇩🇪 Deutsch</button>
    <button class="lang-btn" onclick="setLanguage('it')" data-lang="it">🇮🇹 Italiano</button>
    <button class="lang-btn" onclick="setLanguage('pt')" data-lang="pt">🇵🇹 Português</button>
    <button class="lang-btn" onclick="setLanguage('nl')" data-lang="nl">🇳🇱 Nederlands</button>
    <button class="lang-btn" onclick="setLanguage('pl')" data-lang="pl">🇵🇱 Polski</button>
    <button class="lang-btn" onclick="setLanguage('ru')" data-lang="ru">🇷🇺 Русский</button>
    <button class="lang-btn" onclick="setLanguage('ja')" data-lang="ja">🇯🇵 日本語</button>
    <button class="lang-btn" onclick="setLanguage('zh')" data-lang="zh">🇨🇳 中文</button>
    <button class="lang-btn" onclick="setLanguage('ar')" data-lang="ar">🇸🇦 العربية</button>
</div>
```

### Responsive pour Beaucoup de Langues

Si vous avez beaucoup de langues, modifiez le CSS :

```css
.language-selector {
    display: flex;
    justify-content: center;
    flex-wrap: wrap;  /* Permet le retour à la ligne */
    gap: 10px;
    margin-bottom: 30px;
}

.lang-btn {
    padding: 8px 16px;
    border: 2px solid #667eea;
    background: white;
    color: #667eea;
    border-radius: 8px;
    cursor: pointer;
    font-weight: 600;
    transition: all 0.3s;
    font-size: 14px;  /* Réduire la taille si beaucoup de langues */
}
```

## 📝 Exemple Complet : Ajouter l'Allemand

### 1. Ajouter les traductions

```javascript
de: {
    title: "RuntipiOS Einrichtung",
    subtitle: "Erstkonfiguration",
    'info-step1': "Konfigurieren Sie Ihre SSH-Anmeldedaten für sicheren Fernzugriff.",
    'label-ssh-user': "SSH-Benutzername",
    'label-ssh-pass': "SSH-Passwort",
    'hint-ssh-pass': "Mindestens 8 Zeichen",
    'label-ssh-pass-confirm': "Passwort bestätigen",
    'btn-next-1': "Weiter",
    'info-step2': "Wählen Sie Ihr WLAN-Netzwerk aus und geben Sie das Passwort ein.",
    'label-ssid': "WLAN-Netzwerk (SSID)",
    'option-select': "Netzwerk auswählen...",
    'btn-scan': "🔄 Netzwerke scannen",
    'label-wifi-pass': "WLAN-Passwort",
    'hint-wifi-pass': "Für offene Netzwerke leer lassen",
    'btn-prev-2': "Zurück",
    'btn-next-2': "Weiter",
    'info-step3': "Überprüfen Sie Ihre Konfiguration vor dem Anwenden.",
    'review-title': "Konfigurationsübersicht",
    'review-ssh-user-label': "SSH-Benutzername:",
    'review-ssh-pass-label': "SSH-Passwort:",
    'review-ssid-label': "WLAN-Netzwerk:",
    'review-wifi-pass-label': "WLAN-Passwort:",
    'btn-prev-3': "Zurück",
    'btn-apply': "Konfiguration anwenden",
    'applying-title': "Konfiguration wird angewendet...",
    'applying-text': "Dies kann einen Moment dauern. Bitte warten.",
    'error-passwords': "Passwörter stimmen nicht überein!",
    'error-password-length': "Passwort muss mindestens 8 Zeichen lang sein!",
    'error-ssid': "Bitte wählen Sie ein WLAN-Netzwerk!",
    'error-network': "Verbindungsfehler. Bitte überprüfen Sie Ihre Anmeldedaten.",
    'success-title': "Konfiguration erfolgreich!",
    'success-text': "Das System wird neu gestartet. Sie können darauf zugreifen unter:"
}
```

### 2. Ajouter le bouton

```html
<button class="lang-btn" onclick="setLanguage('de')" data-lang="de">🇩🇪 Deutsch</button>
```

### 3. Tester

Rebuilder l'image et tester le portail captif sur le Raspberry Pi.

## 🔄 Flux de Configuration avec le Nouveau Portail

### Scénario Utilisateur Complet

1. **Premier démarrage** du Raspberry Pi avec RuntipiOS
2. **Aucun réseau configuré** → WiFi-Connect démarre automatiquement
3. **Point d'accès créé** : "RuntipiOS-Setup"
4. **Utilisateur se connecte** avec son smartphone
5. **Portail s'ouvre automatiquement** sur iOS/Android
6. **Sélection de la langue** : 🇬🇧 ou 🇫🇷
7. **Étape 1** : Configuration SSH
   - Saisie nom d'utilisateur (ex: admin)
   - Saisie mot de passe (min 8 caractères)
   - Confirmation mot de passe
8. **Étape 2** : Configuration WiFi
   - Scan automatique des réseaux
   - Sélection du SSID
   - Saisie du mot de passe WiFi
9. **Étape 3** : Résumé et confirmation
   - Vérification de toutes les informations
   - Application de la configuration
10. **Système redémarre** avec la nouvelle configuration
11. **Runtipi s'installe automatiquement** en tâche de fond
12. **Accès final** via `http://runtipios.local` ou `ssh admin@runtipios.local`

## 🛠️ Personnalisation Avancée

### Changer la Langue par Défaut

Dans le JavaScript, modifiez :

```javascript
let currentLang = 'fr';  // Au lieu de 'en'
```

Et dans le HTML :

```html
<button class="lang-btn active" onclick="setLanguage('fr')" data-lang="fr">🇫🇷 Français</button>
<button class="lang-btn" onclick="setLanguage('en')" data-lang="en">🇬🇧 English</button>
```

### Détecter la Langue du Navigateur

Ajoutez au JavaScript :

```javascript
// Détecter la langue du navigateur
window.addEventListener('load', () => {
    const browserLang = navigator.language.split('-')[0]; // 'fr-FR' → 'fr'
    if (translations[browserLang]) {
        setLanguage(browserLang);
    }
    scanNetworks();
});
```

### Persister le Choix de Langue

Utiliser localStorage (si disponible) :

```javascript
function setLanguage(lang) {
    currentLang = lang;
    localStorage.setItem('preferred-lang', lang);
    // ... reste du code
}

// Au chargement
window.addEventListener('load', () => {
    const savedLang = localStorage.getItem('preferred-lang');
    if (savedLang && translations[savedLang]) {
        setLanguage(savedLang);
    }
});
```

### Ajouter un Drapeau pour les Langues RTL

Pour les langues de droite à gauche (arabe, hébreu) :

```javascript
const rtlLanguages = ['ar', 'he', 'fa'];

function setLanguage(lang) {
    currentLang = lang;
    
    // Appliquer RTL si nécessaire
    if (rtlLanguages.includes(lang)) {
        document.body.dir = 'rtl';
    } else {
        document.body.dir = 'ltr';
    }
    
    // ... reste du code
}
```

## 📦 Intégration dans RuntipiOS

Le nouveau script `install-wifi-connect.sh` remplace l'ancien et inclut :

1. ✅ Interface HTML multilingue complète
2. ✅ Backend pour traiter les données SSH et WiFi
3. ✅ Création automatique de l'utilisateur SSH
4. ✅ Configuration WiFi via NetworkManager
5. ✅ Marqueur de configuration (`/etc/runtipi-configured`)
6. ✅ Redémarrage automatique après configuration

### Fichiers Modifiés

- `scripts/install-wifi-connect.sh` → Version améliorée avec UI multilingue

### Utilisation

Le script est **automatiquement appelé** lors du build de l'image via `build-image.sh`.

Aucune modification supplémentaire n'est nécessaire - il suffit de rebuilder l'image !

## 🎨 Personnalisation du Design

### Changer les Couleurs

Dans le CSS, modifiez les variables de couleur :

```css
/* Gradient de fond */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);

/* Couleur principale */
.btn-primary {
    background: #667eea;
}

/* Remplacer par vos couleurs préférées */
background: linear-gradient(135deg, #FF6B6B 0%, #4ECDC4 100%);
```

### Ajouter le Logo Runtipi

Remplacer l'emoji par une image :

```html
<div class="logo">
    <img src="https://runtipi.io/img/logo.png" alt="Runtipi" style="max-width: 200px;">
</div>
```

### Mode Sombre Automatique

Ajouter une media query :

```css
@media (prefers-color-scheme: dark) {
    .container {
        background: #2d2d2d;
        color: #f0f0f0;
    }
    
    input, select {
        background: #3d3d3d;
        color: #f0f0f0;
        border-color: #555;
    }
}
```

## 🐛 Dépannage

### Le portail ne s'affiche pas

1. Vérifier que WiFi-Connect est installé : `which wifi-connect`
2. Vérifier le service : `systemctl status wifi-connect`
3. Vérifier les logs : `journalctl -u wifi-connect -f`

### Les traductions ne s'affichent pas

1. Vérifier la syntaxe JavaScript (pas d'erreurs dans la console)
2. Vérifier que toutes les clés sont présentes
3. Tester dans la console : `translations.fr['title']`

### La langue ne change pas

1. Vérifier que le bouton a le bon `data-lang`
2. Vérifier la fonction `setLanguage` dans la console
3. Tester manuellement : `setLanguage('fr')`

## 📚 Ressources

- [Balena WiFi-Connect](https://github.com/balena-os/wifi-connect)
- [NetworkManager CLI](https://developer.gnome.org/NetworkManager/stable/nmcli.html)
- [Drapeaux Unicode](https://emojipedia.org/flags/)

## 🎉 Félicitations !

Vous avez maintenant un portail captif **complètement personnalisable et multilingue** pour RuntipiOS !

N'hésitez pas à contribuer vos traductions au projet pour aider la communauté internationale ! 🌍
