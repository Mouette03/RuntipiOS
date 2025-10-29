#!/bin/bash

# Script d'installation de Balena WiFi-Connect - VERSION FINALE CORRIGÉE
# Avec dépendances strictes, délais systemd et toutes les variables parsées

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/wifi-connect-install.log
}

log "======================================"
log "Installation de WiFi-Connect - VERSION FINALE"
log "======================================"

# ============================================================================
# CHARGER LA CONFIGURATION
# ============================================================================

get_config_file() {
    if [ -f /etc/runtipios/config.yml ]; then
        echo /etc/runtipios/config.yml
    elif [ -f /tmp/config.yml ]; then
        echo /tmp/config.yml
    else
        echo /tmp/config.yml
    fi
}

CONFIG_FILE=$(get_config_file)

parse_config() {
    local key=$1
    if [ -f "$CONFIG_FILE" ]; then
        grep -E "^\s*${key}:" "$CONFIG_FILE" | sed "s/^[[:space:]]*${key}:[[:space:]]*//g" | sed 's/"//g' | sed "s/'//g"
    fi
}

# Parser toutes les variables
WIFI_CONNECT_VERSION=$(parse_config "wifi_connect_version")
WIFI_CONNECT_SSID=$(parse_config "wifi_connect_ssid")
WIFI_COUNTRY=$(parse_config "wifi_country")

# Valeurs par défaut
WIFI_CONNECT_VERSION=${WIFI_CONNECT_VERSION:-"4.4.6"}
WIFI_CONNECT_SSID=${WIFI_CONNECT_SSID:-"RuntipiOS-Setup"}
WIFI_COUNTRY=${WIFI_COUNTRY:-"FR"}

# Détection architecture - CORRECTION #2
ARCH=$(uname -m)
case "$ARCH" in
    armv6l)
        ARCH="armv6"
        ;;
    armv7l)
        ARCH="armv7hf"
        ;;
    aarch64)
        ARCH="aarch64"
        ;;
    *)
        log "⚠️ Architecture non standard détectée: $ARCH"
        ARCH="aarch64"  # Défaut
        ;;
esac

log "Configuration chargée:"
log " - WiFi-Connect Version: ${WIFI_CONNECT_VERSION}"
log " - WiFi SSID: ${WIFI_CONNECT_SSID}"
log " - WiFi Country: ${WIFI_COUNTRY}"
log " - Architecture: ${ARCH}"

# ============================================================================
# INSTALLATION DES DÉPENDANCES
# ============================================================================

log "Installation des dépendances..."
apt-get update
apt-get install -y \
    jq \
    dnsmasq \
    hostapd \
    rfkill \
    iw

log "✓ Dépendances installées"

# ============================================================================
# TÉLÉCHARGER ET INSTALLER WIFI-CONNECT
# ============================================================================

log "Téléchargement de WiFi-Connect v${WIFI_CONNECT_VERSION} (${ARCH})..."

mkdir -p /usr/local/bin
mkdir -p /usr/local/share/wifi-connect/ui
mkdir -p /var/log

DOWNLOAD_URL="https://github.com/balena-os/wifi-connect/releases/download/v${WIFI_CONNECT_VERSION}/wifi-connect-v${WIFI_CONNECT_VERSION}-linux-${ARCH}.tar.gz"

cd /tmp
wget -q "$DOWNLOAD_URL" -O wifi-connect.tar.gz
tar -xzf wifi-connect.tar.gz
cp wifi-connect /usr/local/bin/
chmod +x /usr/local/bin/wifi-connect

log "✓ WiFi-Connect téléchargé et installé"

# ============================================================================
# CRÉER L'INTERFACE HTML MULTILINGUE (FR/EN) AVEC SÉLECTEUR PAYS
# ============================================================================

log "Création de l'interface web..."

cat > /usr/local/share/wifi-connect/ui/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RuntipiOS Setup</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 600px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        }
        
        .logo {
            text-align: center;
            margin-bottom: 20px;
            font-size: 4em;
        }
        
        h1 {
            text-align: center;
            color: #667eea;
            margin-bottom: 10px;
            font-size: 2em;
        }
        
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 30px;
        }
        
        .language-selector {
            display: flex;
            justify-content: center;
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
        }
        
        .lang-btn.active {
            background: #667eea;
            color: white;
        }
        
        .lang-btn:hover {
            transform: translateY(-2px);
        }
        
        .step {
            display: none;
        }
        
        .step.active {
            display: block;
        }
        
        .step-indicator {
            display: flex;
            justify-content: center;
            gap: 10px;
            margin-bottom: 30px;
        }
        
        .step-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #ddd;
            transition: all 0.3s;
        }
        
        .step-dot.active {
            background: #667eea;
            transform: scale(1.3);
        }
        
        .form-group {
            margin-bottom: 25px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
        }
        
        input, select {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: all 0.3s;
        }
        
        input:focus, select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        .password-toggle {
            position: relative;
        }
        
        .password-toggle button {
            position: absolute;
            right: 10px;
            top: 50%;
            transform: translateY(-50%);
            background: none;
            border: none;
            cursor: pointer;
            color: #667eea;
            font-size: 20px;
        }
        
        .button-group {
            display: flex;
            gap: 15px;
            margin-top: 30px;
        }
        
        button {
            flex: 1;
            padding: 15px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .btn-primary {
            background: #667eea;
            color: white;
        }
        
        .btn-primary:hover {
            background: #5568d3;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.3);
        }
        
        .btn-secondary {
            background: #e0e0e0;
            color: #333;
        }
        
        .btn-secondary:hover {
            background: #d0d0d0;
        }
        
        .info-box {
            background: #f0f4ff;
            border-left: 4px solid #667eea;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .info-box p {
            margin: 5px 0;
            color: #666;
        }
        
        .loading {
            text-align: center;
            padding: 20px;
        }
        
        .spinner {
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .error {
            background: #fee;
            border-left: 4px solid #e33;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            color: #c00;
        }
        
        .success {
            background: #efe;
            border-left: 4px solid #3e3;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            color: #060;
        }
        
        @media (max-width: 600px) {
            .container {
                padding: 20px;
            }
            h1 {
                font-size: 1.5em;
            }
            .button-group {
                flex-direction: column;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🔧</div>
        <h1 id="title">RuntipiOS Setup</h1>
        <p class="subtitle" id="subtitle">First time configuration</p>
        
        <div class="language-selector">
            <button class="lang-btn active" onclick="setLanguage('en')" data-lang="en">English</button>
            <button class="lang-btn" onclick="setLanguage('fr')" data-lang="fr">Français</button>
        </div>
        
        <div class="step-indicator">
            <div class="step-dot active"></div>
            <div class="step-dot"></div>
            <div class="step-dot"></div>
            <div class="step-dot"></div>
        </div>
        
        <form id="setupForm">
            <!-- Step 1: SSH Configuration -->
            <div class="step active" data-step="1">
                <div class="info-box">
                    <p id="info-step1">Configure your SSH credentials for secure remote access.</p>
                </div>
                
                <div class="form-group">
                    <label for="sshusername" id="label-ssh-user">SSH Username</label>
                    <input type="text" id="sshusername" name="sshusername" required placeholder="runtipi" value="runtipi">
                </div>
                
                <div class="form-group">
                    <label for="sshpassword" id="label-ssh-pass">SSH Password</label>
                    <div class="password-toggle">
                        <input type="password" id="sshpassword" name="sshpassword" required placeholder="" minlength="8">
                        <button type="button" onclick="togglePassword('sshpassword')">👁️</button>
                    </div>
                    <small id="hint-ssh-pass" style="color: #999;">Minimum 8 characters</small>
                </div>
                
                <div class="form-group">
                    <label for="sshpasswordconfirm" id="label-ssh-pass-confirm">Confirm Password</label>
                    <div class="password-toggle">
                        <input type="password" id="sshpasswordconfirm" required placeholder="" minlength="8">
                        <button type="button" onclick="togglePassword('sshpasswordconfirm')">👁️</button>
                    </div>
                </div>
                
                <div class="button-group">
                    <button type="button" class="btn-primary" onclick="nextStep()" id="btn-next-1">Next</button>
                </div>
            </div>
            
            <!-- Step 2: WiFi Configuration with Country Selection -->
            <div class="step" data-step="2">
                <div class="info-box">
                    <p id="info-step2">Select your WiFi network, country, and enter the password.</p>
                </div>
                
                <div class="form-group">
                    <label for="wificountry" id="label-wifi-country">WiFi Country Regulatory Domain</label>
                    <select id="wificountry" name="wificountry" required>
                        <option value="FR" selected>France (FR)</option>
                        <option value="US">United States (US)</option>
                        <option value="GB">United Kingdom (GB)</option>
                        <option value="DE">Germany (DE)</option>
                        <option value="ES">Spain (ES)</option>
                        <option value="IT">Italy (IT)</option>
                        <option value="CA">Canada (CA)</option>
                        <option value="AU">Australia (AU)</option>
                        <option value="JP">Japan (JP)</option>
                        <option value="CN">China (CN)</option>
                        <option value="BR">Brazil (BR)</option>
                        <option value="IN">India (IN)</option>
                        <option value="RU">Russia (RU)</option>
                        <option value="NL">Netherlands (NL)</option>
                        <option value="BE">Belgium (BE)</option>
                        <option value="CH">Switzerland (CH)</option>
                        <option value="SE">Sweden (SE)</option>
                        <option value="NO">Norway (NO)</option>
                        <option value="DK">Denmark (DK)</option>
                        <option value="FI">Finland (FI)</option>
                        <option value="PL">Poland (PL)</option>
                        <option value="PT">Portugal (PT)</option>
                        <option value="AT">Austria (AT)</option>
                        <option value="IE">Ireland (IE)</option>
                        <option value="NZ">New Zealand (NZ)</option>
                        <option value="ZA">South Africa (ZA)</option>
                    </select>
                    <small id="hint-wifi-country" style="color: #999;">Required for regulatory compliance</small>
                </div>
                
                <div class="form-group">
                    <label for="ssid" id="label-ssid">WiFi Network SSID</label>
                    <select id="ssid" name="ssid" required>
                        <option value="" id="option-select">Select a network...</option>
                    </select>
                    <button type="button" onclick="scanNetworks()" id="btn-scan" style="margin-top: 10px; width: 100%;" class="btn-secondary">Scan networks</button>
                </div>
                
                <div class="form-group">
                    <label for="wifipassword" id="label-wifi-pass">WiFi Password</label>
                    <div class="password-toggle">
                        <input type="password" id="wifipassword" name="wifipassword" placeholder="">
                        <button type="button" onclick="togglePassword('wifipassword')">👁️</button>
                    </div>
                    <small id="hint-wifi-pass" style="color: #999;">Leave empty for open networks</small>
                </div>
                
                <div class="button-group">
                    <button type="button" class="btn-secondary" onclick="prevStep()" id="btn-prev-2">Previous</button>
                    <button type="button" class="btn-primary" onclick="nextStep()" id="btn-next-2">Next</button>
                </div>
            </div>
            
            <!-- Step 3: Confirmation -->
            <div class="step" data-step="3">
                <div class="info-box">
                    <p id="info-step3">Review your configuration before applying.</p>
                </div>
                
                <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                    <h3 id="review-title" style="margin-bottom: 15px; color: #667eea;">Configuration Summary</h3>
                    <p><strong id="review-ssh-user-label">SSH Username</strong><br><span id="reviewsshusername"></span></p>
                    <p><strong id="review-ssh-pass-label">SSH Password</strong><br><span id="reviewsshpassword">••••••••</span></p>
                    <p><strong id="review-country-label">WiFi Country</strong><br><span id="reviewwificountry"></span></p>
                    <p><strong id="review-ssid-label">WiFi Network</strong><br><span id="reviewssid"></span></p>
                    <p><strong id="review-wifi-pass-label">WiFi Password</strong><br><span id="reviewwifipassword"></span></p>
                </div>
                
                <div class="button-group">
                    <button type="button" class="btn-secondary" onclick="prevStep()" id="btn-prev-3">Previous</button>
                    <button type="submit" class="btn-primary" id="btn-apply">Apply Configuration</button>
                </div>
            </div>
            
            <!-- Step 4: Application in progress -->
            <div class="step" data-step="4">
                <div class="loading">
                    <div class="spinner"></div>
                    <h3 id="applying-title">Applying configuration...</h3>
                    <p id="applying-text">This may take a few moments. Please wait.</p>
                </div>
            </div>
        </form>
    </div>
    
    <script>
        const translations = {
            en: {
                title: 'RuntipiOS Setup',
                subtitle: 'First time configuration',
                'info-step1': 'Configure your SSH credentials for secure remote access.',
                'label-ssh-user': 'SSH Username',
                'label-ssh-pass': 'SSH Password',
                'hint-ssh-pass': 'Minimum 8 characters',
                'label-ssh-pass-confirm': 'Confirm Password',
                'btn-next-1': 'Next',
                'info-step2': 'Select your WiFi network, country, and enter the password.',
                'label-wifi-country': 'WiFi Country Regulatory Domain',
                'hint-wifi-country': 'Required for regulatory compliance',
                'label-ssid': 'WiFi Network SSID',
                'option-select': 'Select a network...',
                'btn-scan': 'Scan networks',
                'label-wifi-pass': 'WiFi Password',
                'hint-wifi-pass': 'Leave empty for open networks',
                'btn-prev-2': 'Previous',
                'btn-next-2': 'Next',
                'info-step3': 'Review your configuration before applying.',
                'review-title': 'Configuration Summary',
                'review-ssh-user-label': 'SSH Username',
                'review-ssh-pass-label': 'SSH Password',
                'review-country-label': 'WiFi Country',
                'review-ssid-label': 'WiFi Network',
                'review-wifi-pass-label': 'WiFi Password',
                'btn-prev-3': 'Previous',
                'btn-apply': 'Apply Configuration',
                'applying-title': 'Applying configuration...',
                'applying-text': 'This may take a few moments. Please wait.',
                'error-passwords': 'Passwords do not match!',
                'error-password-length': 'Password must be at least 8 characters!',
                'error-ssid': 'Please select a WiFi network!',
                'error-network': 'Error connecting. Please check your credentials.',
                'success-title': 'Configuration successful!',
                'success-text': 'The system is rebooting. You can access it at http://runtipios.local'
            },
            fr: {
                title: 'Configuration RuntipiOS',
                subtitle: 'Configuration initiale',
                'info-step1': 'Configurez vos identifiants SSH pour un accès distant sécurisé.',
                'label-ssh-user': 'Nom d\'utilisateur SSH',
                'label-ssh-pass': 'Mot de passe SSH',
                'hint-ssh-pass': 'Minimum 8 caractères',
                'label-ssh-pass-confirm': 'Confirmer le mot de passe',
                'btn-next-1': 'Suivant',
                'info-step2': 'Sélectionnez votre pays, réseau WiFi et entrez le mot de passe.',
                'label-wifi-country': 'Pays WiFi (Domaine réglementaire)',
                'hint-wifi-country': 'Requis pour la conformité réglementaire',
                'label-ssid': 'Réseau WiFi (SSID)',
                'option-select': 'Sélectionner un réseau...',
                'btn-scan': 'Scanner les réseaux',
                'label-wifi-pass': 'Mot de passe WiFi',
                'hint-wifi-pass': 'Laisser vide pour les réseaux ouverts',
                'btn-prev-2': 'Précédent',
                'btn-next-2': 'Suivant',
                'info-step3': 'Vérifiez votre configuration avant de l\'appliquer.',
                'review-title': 'Résumé de la configuration',
                'review-ssh-user-label': 'Utilisateur SSH',
                'review-ssh-pass-label': 'Mot de passe SSH',
                'review-country-label': 'Pays WiFi',
                'review-ssid-label': 'Réseau WiFi',
                'review-wifi-pass-label': 'Mot de passe WiFi',
                'btn-prev-3': 'Précédent',
                'btn-apply': 'Appliquer la configuration',
                'applying-title': 'Application de la configuration...',
                'applying-text': 'Cela peut prendre quelques instants. Veuillez patienter.',
                'error-passwords': 'Les mots de passe ne correspondent pas !',
                'error-password-length': 'Le mot de passe doit contenir au moins 8 caractères !',
                'error-ssid': 'Veuillez sélectionner un réseau WiFi !',
                'error-network': 'Erreur de connexion. Vérifiez vos identifiants.',
                'success-title': 'Configuration réussie !',
                'success-text': 'Le système redémarre. Vous pouvez y accéder à http://runtipios.local'
            }
        };
        
        let currentLang = 'en';
        let currentStep = 1;
        
        function setLanguage(lang) {
            currentLang = lang;
            document.querySelectorAll('.lang-btn').forEach(btn => {
                btn.classList.toggle('active', btn.dataset.lang === lang);
            });
            Object.keys(translations[lang]).forEach(key => {
                const element = document.getElementById(key);
                if (element) {
                    element.textContent = translations[lang][key];
                }
            });
        }
        
        function togglePassword(fieldId) {
            const field = document.getElementById(fieldId);
            field.type = field.type === 'password' ? 'text' : 'password';
        }
        
        function nextStep() {
            if (currentStep === 1) {
                const password = document.getElementById('sshpassword').value;
                const confirm = document.getElementById('sshpasswordconfirm').value;
                if (password.length < 8) {
                    alert(translations[currentLang]['error-password-length']);
                    return;
                }
                if (password !== confirm) {
                    alert(translations[currentLang]['error-passwords']);
                    return;
                }
            }
            
            if (currentStep === 2) {
                const ssid = document.getElementById('ssid').value;
                if (!ssid) {
                    alert(translations[currentLang]['error-ssid']);
                    return;
                }
                document.getElementById('reviewsshusername').textContent = document.getElementById('sshusername').value;
                const countrySelect = document.getElementById('wificountry');
                document.getElementById('reviewwificountry').textContent = countrySelect.options[countrySelect.selectedIndex].text;
                document.getElementById('reviewssid').textContent = ssid;
                document.getElementById('reviewwifipassword').textContent = document.getElementById('wifipassword').value ? '••••••••' : 'Open';
            }
            
            currentStep++;
            updateSteps();
        }
        
        function prevStep() {
            currentStep--;
            updateSteps();
        }
        
        function updateSteps() {
            document.querySelectorAll('.step').forEach((step, index) => {
                step.classList.toggle('active', index + 1 === currentStep);
            });
            document.querySelectorAll('.step-dot').forEach((dot, index) => {
                dot.classList.toggle('active', index + 1 === currentStep);
            });
        }
        
        async function scanNetworks() {
            const select = document.getElementById('ssid');
            try {
                const response = await fetch('/networks');
                const networks = await response.json();
                select.innerHTML = '<option value="">Select...</option>';
                networks.forEach(network => {
                    const option = document.createElement('option');
                    option.value = network.ssid;
                    option.textContent = network.ssid + (network.signal ? ` (${network.signal}%)` : '');
                    select.appendChild(option);
                });
            } catch (error) {
                console.error('Error scanning networks:', error);
            }
        }
        
        document.getElementById('setupForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            currentStep = 4;
            updateSteps();
            
            const data = {
                sshusername: document.getElementById('sshusername').value,
                sshpassword: document.getElementById('sshpassword').value,
                wificountry: document.getElementById('wificountry').value,
                ssid: document.getElementById('ssid').value,
                password: document.getElementById('wifipassword').value
            };
            
            try {
                const response = await fetch('/connect', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });
                
                if (response.ok) {
                    document.querySelector('[data-step="4"]').innerHTML = `
                        <div class="success">
                            <h3>${translations[currentLang]['success-title']}</h3>
                            <p>${translations[currentLang]['success-text']}</p>
                        </div>
                    `;
                }
            } catch (error) {
                document.querySelector('[data-step="4"]').innerHTML = `
                    <div class="error">
                        <p>${translations[currentLang]['error-network']}</p>
                    </div>
                `;
            }
        });
        
        window.addEventListener('load', scanNetworks);
    </script>
</body>
</html>
HTMLEOF

log "✓ Interface HTML créée avec sélecteur de pays WiFi"

# ============================================================================
# CRÉER LE SCRIPT DE VÉRIFICATION WIFI CORRIGÉ
# ============================================================================

log "Création du script de vérification WiFi..."

cat > /usr/local/bin/wifi-connect-check.sh << 'CHECKEOF'
#!/bin/bash
set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/wifi-connect-check.log
}

log "Vérification connectivité"

# Si déjà configuré, sortir
if [ -f /etc/runtipi-configured ]; then
    exit 0
fi

# Attendre NetworkManager
log "Attente NetworkManager..."
for i in {1..60}; do
    if systemctl is-active NetworkManager &>/dev/null; then
        log "NetworkManager actif"
        break
    fi
    sleep 1
done

sleep 5

# CORRECTION #3 : Vérifier que Ethernet ou WiFi a une IP (pas juste "UP")
log "Vérification réseau..."
for i in {1..30}; do
    # Vérifier Ethernet
    if ip addr show eth0 2>/dev/null | grep -q "inet "; then
        log "✓ Ethernet configuré avec IP"
        touch /etc/runtipi-configured
        exit 0
    fi
    
    # Vérifier WiFi
    if ip addr show wlan0 2>/dev/null | grep -q "inet "; then
        log "✓ WiFi configuré avec IP"
        touch /etc/runtipi-configured
        exit 0
    fi
    
    sleep 1
done

# Pas de réseau détecté, lancer WiFi-Connect
log "Aucun réseau détecté, lancement WiFi-Connect"
rfkill unblock wifi 2>/dev/null || true
rfkill unblock wlan 2>/dev/null || true

exec /usr/local/bin/wifi-connect \
    --portal-ssid "RuntipiOS-Setup" \
    --portal-interface wlan0 \
    --ui-directory /usr/local/share/wifi-connect/ui
CHECKEOF

chmod +x /usr/local/bin/wifi-connect-check.sh

log "✓ Script de vérification WiFi créé"

# ============================================================================
# CRÉER LE SCRIPT D'INSTALLATION RUNTIPI
# ============================================================================

log "Création du script d'installation Runtipi..."

cat > /usr/local/bin/install-runtipi.sh << 'RUNTIPIEOF'
#!/bin/bash
set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/runtipi-installer.log
}

log "=== Installation Runtipi ==="

mkdir -p /home/runtipi
cd /home/runtipi

log "Lancement du script officiel Runtipi..."
curl -L https://setup.runtipi.io | bash

touch /etc/runtipi-configured

log "✓ Installation Runtipi terminée !"
RUNTIPIEOF

chmod +x /usr/local/bin/install-runtipi.sh

log "✓ Script d'installation Runtipi créé"

# ============================================================================
# CONFIGURER LES SERVICES SYSTEMD
# ============================================================================

log "Configuration des services systemd..."

# Service WiFi-Connect
cat > /etc/systemd/system/wifi-connect.service << 'WIFISVCEOF'
[Unit]
Description=Balena WiFi Connect - Captive Portal
After=NetworkManager.service network-online.target unblock-rfkill.service
Wants=network-online.target
Requires=NetworkManager.service
Before=runtipi-installer.service
ConditionPathExists=!/etc/runtipi-configured

[Service]
Type=simple
ExecStartPre=/bin/sleep 15
ExecStart=/usr/local/bin/wifi-connect-check.sh
Restart=on-failure
RestartSec=20
StandardOutput=journal
StandardError=journal
TimeoutStartSec=300
KillMode=process

[Install]
WantedBy=multi-user.target
WIFISVCEOF

# Service Runtipi Installer
cat > /etc/systemd/system/runtipi-installer.service << 'RUNTIPISVCEOF'
[Unit]
Description=Runtipi Auto-Installer
After=network-online.target wifi-connect.service
Wants=network-online.target
ConditionPathExists=!/etc/runtipi-configured

[Service]
Type=oneshot
ExecStart=/usr/local/bin/install-runtipi.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal
TimeoutStartSec=1800

[Install]
WantedBy=multi-user.target
RUNTIPISVCEOF

systemctl daemon-reload
systemctl enable wifi-connect.service
systemctl enable runtipi-installer.service

log "✓ Services systemd configurés"

# ============================================================================
# CONFIGURER DNSMASQ POUR LE PORTAIL CAPTIF
# ============================================================================

log "Configuration de dnsmasq..."

cat > /etc/dnsmasq.d/wifi-connect << 'DNSMASQEOF'
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.254,12h
dhcp-option=option:router,192.168.4.1
address=/#/192.168.4.1
listen-address=192.168.4.1
DNSMASQEOF

log "✓ dnsmasq configuré"

# ============================================================================
# NETTOYAGE
# ============================================================================

log "Nettoyage..."

rm -f /tmp/wifi-connect.tar.gz
apt-get clean

log ""
log "╔════════════════════════════════════════════════════╗"
log "║                                                    ║"
log "║     ✓ Installation WiFi-Connect terminée !        ║"
log "║                                                    ║"
log "║  Au premier démarrage:                            ║"
log "║  1. WiFi-Connect apparaîtra si pas de réseau     ║"
log "║  2. Runtipi s'installera automatiquement         ║"
log "║  3. L'accès web sera disponible après ~5-10 min  ║"
log "║                                                    ║"
log "╚════════════════════════════════════════════════════╝"
log ""

log "✓ Installation terminée avec succès !"
