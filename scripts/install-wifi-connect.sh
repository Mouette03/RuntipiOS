#!/bin/bash
# Script d'installation de Balena WiFi-Connect
# Avec dépendances strictes et délais systemd

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "======================================"
log "Installation de WiFi-Connect"
log "======================================"

# Charger la configuration
if [ -f /tmp/config.yml ]; then
    eval $(grep -E "^\s*version:" /tmp/config.yml | grep wifi_connect -A 1 | tail -1 | sed 's/^[[:space:]]*version:[[:space:]]*/WIFI_CONNECT_VERSION=/' | sed 's/"//g')
    eval $(grep -E "^\s*ssid:" /tmp/config.yml | sed 's/^[[:space:]]*ssid:[[:space:]]*/WIFI_CONNECT_SSID=/' | sed 's/"//g')
fi

WIFI_CONNECT_VERSION=${WIFI_CONNECT_VERSION:-"4.4.6"}
WIFI_CONNECT_SSID=${WIFI_CONNECT_SSID:-"RuntipiOS-Setup"}
ARCH="aarch64"

# Déterminer l'architecture
if [ "$(uname -m)" = "armv7l" ]; then
    ARCH="armv7hf"
fi

log "Version: ${WIFI_CONNECT_VERSION}"
log "SSID: ${WIFI_CONNECT_SSID}"
log "Architecture: ${ARCH}"

# ============================================================================
# INSTALLER LES DÉPENDANCES REQUISES
# ============================================================================
log "Installation des dépendances (jq, dnsmasq, etc.)..."
apt-get update
apt-get install -y jq dnsmasq

# Télécharger WiFi-Connect
log "Téléchargement de WiFi-Connect..."
DOWNLOAD_URL="https://github.com/balena-os/wifi-connect/releases/download/v${WIFI_CONNECT_VERSION}/wifi-connect-v${WIFI_CONNECT_VERSION}-linux-${ARCH}.tar.gz"

wget -O /tmp/wifi-connect.tar.gz "$DOWNLOAD_URL"

# Extraire
log "Extraction..."
tar -xzf /tmp/wifi-connect.tar.gz -C /usr/local/bin/
chmod +x /usr/local/bin/wifi-connect

# Créer le répertoire pour l'interface utilisateur personnalisée
mkdir -p /usr/local/share/wifi-connect/ui

# Créer l'interface HTML personnalisée AVEC SÉLECTEUR DE PAYS
log "Création de l'interface web personnalisée..."
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
        <div class="logo">🚀</div>
        <h1 id="title">RuntipiOS Setup</h1>
        <p class="subtitle" id="subtitle">First time configuration</p>
        
        <div class="language-selector">
            <button class="lang-btn active" onclick="setLanguage('en')" data-lang="en">🇬🇧 English</button>
            <button class="lang-btn" onclick="setLanguage('fr')" data-lang="fr">🇫🇷 Français</button>
        </div>
        
        <div class="step-indicator">
            <div class="step-dot active"></div>
            <div class="step-dot"></div>
            <div class="step-dot"></div>
        </div>
        
        <form id="setupForm">
            <!-- Étape 1: Configuration SSH -->
            <div class="step active" data-step="1">
                <div class="info-box">
                    <p id="info-step1">Configure your SSH credentials for secure remote access.</p>
                </div>
                
                <div class="form-group">
                    <label for="ssh_username" id="label-ssh-user">SSH Username</label>
                    <input type="text" id="ssh_username" name="ssh_username" required 
                           placeholder="runtipi" value="runtipi">
                </div>
                
                <div class="form-group">
                    <label for="ssh_password" id="label-ssh-pass">SSH Password</label>
                    <div class="password-toggle">
                        <input type="password" id="ssh_password" name="ssh_password" required 
                               placeholder="••••••••" minlength="8">
                        <button type="button" onclick="togglePassword('ssh_password')">👁️</button>
                    </div>
                    <small id="hint-ssh-pass" style="color: #999;">Minimum 8 characters</small>
                </div>
                
                <div class="form-group">
                    <label for="ssh_password_confirm" id="label-ssh-pass-confirm">Confirm Password</label>
                    <div class="password-toggle">
                        <input type="password" id="ssh_password_confirm" required 
                               placeholder="••••••••" minlength="8">
                        <button type="button" onclick="togglePassword('ssh_password_confirm')">👁️</button>
                    </div>
                </div>
                
                <div class="button-group">
                    <button type="button" class="btn-primary" onclick="nextStep()" id="btn-next-1">Next</button>
                </div>
            </div>
            
            <!-- Étape 2: Configuration WiFi + PAYS -->
            <div class="step" data-step="2">
                <div class="info-box">
                    <p id="info-step2">Select your WiFi network, country, and enter the password.</p>
                </div>
                
                <div class="form-group">
                    <label for="wifi_country" id="label-wifi-country">WiFi Country / Regulatory Domain</label>
                    <select id="wifi_country" name="wifi_country" required>
                        <option value="FR" selected>🇫🇷 France (FR)</option>
                        <option value="US">🇺🇸 United States (US)</option>
                        <option value="GB">🇬🇧 United Kingdom (GB)</option>
                        <option value="DE">🇩🇪 Germany (DE)</option>
                        <option value="ES">🇪🇸 Spain (ES)</option>
                        <option value="IT">🇮🇹 Italy (IT)</option>
                        <option value="CA">🇨🇦 Canada (CA)</option>
                        <option value="AU">🇦🇺 Australia (AU)</option>
                        <option value="JP">🇯🇵 Japan (JP)</option>
                        <option value="CN">🇨🇳 China (CN)</option>
                        <option value="BR">🇧🇷 Brazil (BR)</option>
                        <option value="IN">🇮🇳 India (IN)</option>
                        <option value="RU">🇷🇺 Russia (RU)</option>
                        <option value="NL">🇳🇱 Netherlands (NL)</option>
                        <option value="BE">🇧🇪 Belgium (BE)</option>
                        <option value="CH">🇨🇭 Switzerland (CH)</option>
                        <option value="SE">🇸🇪 Sweden (SE)</option>
                        <option value="NO">🇳🇴 Norway (NO)</option>
                        <option value="DK">🇩🇰 Denmark (DK)</option>
                        <option value="FI">🇫🇮 Finland (FI)</option>
                        <option value="PL">🇵🇱 Poland (PL)</option>
                        <option value="PT">🇵🇹 Portugal (PT)</option>
                        <option value="AT">🇦🇹 Austria (AT)</option>
                        <option value="IE">🇮🇪 Ireland (IE)</option>
                        <option value="NZ">🇳🇿 New Zealand (NZ)</option>
                        <option value="ZA">🇿🇦 South Africa (ZA)</option>
                    </select>
                    <small id="hint-wifi-country" style="color: #999;">Required for regulatory compliance</small>
                </div>
                
                <div class="form-group">
                    <label for="ssid" id="label-ssid">WiFi Network (SSID)</label>
                    <select id="ssid" name="ssid" required>
                        <option value="" id="option-select">Select a network...</option>
                    </select>
                    <button type="button" onclick="scanNetworks()" id="btn-scan" 
                            style="margin-top: 10px; width: 100%;" class="btn-secondary">
                        🔄 Scan networks
                    </button>
                </div>
                
                <div class="form-group">
                    <label for="wifi_password" id="label-wifi-pass">WiFi Password</label>
                    <div class="password-toggle">
                        <input type="password" id="wifi_password" name="wifi_password" 
                               placeholder="••••••••">
                        <button type="button" onclick="togglePassword('wifi_password')">👁️</button>
                    </div>
                    <small id="hint-wifi-pass" style="color: #999;">Leave empty for open networks</small>
                </div>
                
                <div class="button-group">
                    <button type="button" class="btn-secondary" onclick="prevStep()" id="btn-prev-2">Previous</button>
                    <button type="button" class="btn-primary" onclick="nextStep()" id="btn-next-2">Next</button>
                </div>
            </div>
            
            <!-- Étape 3: Confirmation -->
            <div class="step" data-step="3">
                <div class="info-box">
                    <p id="info-step3">Review your configuration before applying.</p>
                </div>
                
                <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                    <h3 id="review-title" style="margin-bottom: 15px; color: #667eea;">Configuration Summary</h3>
                    <p><strong id="review-ssh-user-label">SSH Username:</strong> <span id="review_ssh_username"></span></p>
                    <p><strong id="review-ssh-pass-label">SSH Password:</strong> ••••••••</p>
                    <p><strong id="review-country-label">WiFi Country:</strong> <span id="review_wifi_country"></span></p>
                    <p><strong id="review-ssid-label">WiFi Network:</strong> <span id="review_ssid"></span></p>
                    <p><strong id="review-wifi-pass-label">WiFi Password:</strong> <span id="review_wifi_password"></span></p>
                </div>
                
                <div class="button-group">
                    <button type="button" class="btn-secondary" onclick="prevStep()" id="btn-prev-3">Previous</button>
                    <button type="submit" class="btn-primary" id="btn-apply">Apply Configuration</button>
                </div>
            </div>
            
            <!-- Étape 4: Application en cours -->
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
                title: "RuntipiOS Setup",
                subtitle: "First time configuration",
                'info-step1': "Configure your SSH credentials for secure remote access.",
                'label-ssh-user': "SSH Username",
                'label-ssh-pass': "SSH Password",
                'hint-ssh-pass': "Minimum 8 characters",
                'label-ssh-pass-confirm': "Confirm Password",
                'btn-next-1': "Next",
                'info-step2': "Select your WiFi network, country, and enter the password.",
                'label-wifi-country': "WiFi Country / Regulatory Domain",
                'hint-wifi-country': "Required for regulatory compliance",
                'label-ssid': "WiFi Network (SSID)",
                'option-select': "Select a network...",
                'btn-scan': "🔄 Scan networks",
                'label-wifi-pass': "WiFi Password",
                'hint-wifi-pass': "Leave empty for open networks",
                'btn-prev-2': "Previous",
                'btn-next-2': "Next",
                'info-step3': "Review your configuration before applying.",
                'review-title': "Configuration Summary",
                'review-ssh-user-label': "SSH Username:",
                'review-ssh-pass-label': "SSH Password:",
                'review-country-label': "WiFi Country:",
                'review-ssid-label': "WiFi Network:",
                'review-wifi-pass-label': "WiFi Password:",
                'btn-prev-3': "Previous",
                'btn-apply': "Apply Configuration",
                'applying-title': "Applying configuration...",
                'applying-text': "This may take a few moments. Please wait.",
                'error-passwords': "Passwords do not match!",
                'error-password-length': "Password must be at least 8 characters!",
                'error-ssid': "Please select a WiFi network!",
                'error-network': "Error connecting. Please check your credentials.",
                'success-title': "Configuration successful!",
                'success-text': "The system is rebooting. You can access it at:"
            },
            fr: {
                title: "Configuration RuntipiOS",
                subtitle: "Configuration initiale",
                'info-step1': "Configurez vos identifiants SSH pour un accès distant sécurisé.",
                'label-ssh-user': "Nom d'utilisateur SSH",
                'label-ssh-pass': "Mot de passe SSH",
                'hint-ssh-pass': "Minimum 8 caractères",
                'label-ssh-pass-confirm': "Confirmer le mot de passe",
                'btn-next-1': "Suivant",
                'info-step2': "Sélectionnez votre pays, réseau WiFi et entrez le mot de passe.",
                'label-wifi-country': "Pays WiFi / Domaine réglementaire",
                'hint-wifi-country': "Requis pour la conformité réglementaire",
                'label-ssid': "Réseau WiFi (SSID)",
                'option-select': "Sélectionner un réseau...",
                'btn-scan': "🔄 Scanner les réseaux",
                'label-wifi-pass': "Mot de passe WiFi",
                'hint-wifi-pass': "Laisser vide pour les réseaux ouverts",
                'btn-prev-2': "Précédent",
                'btn-next-2': "Suivant",
                'info-step3': "Vérifiez votre configuration avant de l'appliquer.",
                'review-title': "Résumé de la configuration",
                'review-ssh-user-label': "Utilisateur SSH :",
                'review-ssh-pass-label': "Mot de passe SSH :",
                'review-country-label': "Pays WiFi :",
                'review-ssid-label': "Réseau WiFi :",
                'review-wifi-pass-label': "Mot de passe WiFi :",
                'btn-prev-3': "Précédent",
                'btn-apply': "Appliquer la configuration",
                'applying-title': "Application de la configuration...",
                'applying-text': "Cela peut prendre quelques instants. Veuillez patienter.",
                'error-passwords': "Les mots de passe ne correspondent pas !",
                'error-password-length': "Le mot de passe doit contenir au moins 8 caractères !",
                'error-ssid': "Veuillez sélectionner un réseau WiFi !",
                'error-network': "Erreur de connexion. Vérifiez vos identifiants.",
                'success-title': "Configuration réussie !",
                'success-text': "Le système redémarre. Vous pouvez y accéder à :"
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
                const password = document.getElementById('ssh_password').value;
                const confirm = document.getElementById('ssh_password_confirm').value;
                if (password.length < 8 || password !== confirm) {
                    alert(translations[currentLang]['error-password-length']);
                    return;
                }
            }
            if (currentStep === 2) {
                const ssid = document.getElementById('ssid').value;
                if (!ssid) {
                    alert(translations[currentLang]['error-ssid']);
                    return;
                }
                document.getElementById('review_ssh_username').textContent = document.getElementById('ssh_username').value;
                const countrySelect = document.getElementById('wifi_country');
                document.getElementById('review_wifi_country').textContent = countrySelect.options[countrySelect.selectedIndex].text;
                document.getElementById('review_ssid').textContent = ssid;
                document.getElementById('review_wifi_password').textContent = document.getElementById('wifi_password').value ? '••••••••' : '(Open)';
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
                    option.textContent = `${network.ssid} (${network.signal}%)`;
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
                ssh_username: document.getElementById('ssh_username').value,
                ssh_password: document.getElementById('ssh_password').value,
                wifi_country: document.getElementById('wifi_country').value,
                ssid: document.getElementById('ssid').value,
                password: document.getElementById('wifi_password').value
            };
            
            try {
                const response = await fetch('/connect', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });
                
                if (response.ok) {
                    document.querySelector('[data-step="4"]').innerHTML = `<div class="success"><h3>${translations[currentLang]['success-title']}</h3><p>${translations[currentLang]['success-text']}</p><p style="margin-top: 15px;"><strong>http://runtipios.local</strong></p></div>`;
                }
            } catch (error) {
                document.querySelector('[data-step="4"]').innerHTML = `<div class="error"><p>${translations[currentLang]['error-network']}</p></div>`;
            }
        });
        
        window.addEventListener('load', () => scanNetworks());
    </script>
</body>
</html>
HTMLEOF

log "✓ Interface HTML créée"

# Créer le backend CORRIGÉ avec attente NetworkManager
cat > /usr/local/bin/wifi-connect-backend.sh << 'BACKENDEOF'
#!/bin/bash
set -e

log() {
    echo "[$(date)] $1" | tee -a /var/log/wifi-connect-backend.log
}

CONFIG_FILE="/tmp/wifi-connect-config.json"

apply_wifi_country() {
    local country=$1
    log "Configuration du pays WiFi: $country"
    
    if command -v raspi-config &>/dev/null; then
        raspi-config nonint do_wifi_country "$country" 2>&1 || true
    fi
    
    mkdir -p /etc/wpa_supplicant
    if grep -q "^country=" /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null; then
        sed -i "s/^country=.*/country=$country/" /etc/wpa_supplicant/wpa_supplicant.conf
    else
        echo "country=$country" >> /etc/wpa_supplicant/wpa_supplicant.conf
    fi
    
    if [ -f /boot/firmware/config.txt ]; then
        sed -i '/^country=/d' /boot/firmware/config.txt
        echo "country=$country" >> /boot/firmware/config.txt
    fi
    
    rfkill unblock wifi 2>/dev/null || true
    rfkill unblock wlan 2>/dev/null || true
    
    log "✓ Pays WiFi: $country"
}

apply_ssh_config() {
    local username=$1
    local password=$2
    
    log "Configuration SSH: $username"
    
    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash -G sudo,netdev "$username"
    fi
    
    echo "$username:$password" | chpasswd
    mkdir -p /home/$username/.ssh
    chmod 700 /home/$username/.ssh
    chown -R $username:$username /home/$username/.ssh
    
    log "✓ SSH configuré"
}

apply_wifi_config() {
    local ssid=$1
    local password=$2
    
    log "Connexion WiFi: $ssid"
    
    for i in {1..30}; do
        if systemctl is-active NetworkManager &>/dev/null; then
            break
        fi
        sleep 1
    done
    
    if [ -n "$password" ]; then
        nmcli device wifi connect "$ssid" password "$password" 2>&1 || true
    else
        nmcli device wifi connect "$ssid" 2>&1 || true
    fi
    
    log "✓ WiFi configuré"
}

if [ "$1" = "apply" ] && [ -f "$CONFIG_FILE" ]; then
    CONFIG=$(cat "$CONFIG_FILE")
    
    SSH_USERNAME=$(echo "$CONFIG" | jq -r '.ssh_username // "runtipi"')
    SSH_PASSWORD=$(echo "$CONFIG" | jq -r '.ssh_password')
    WIFI_COUNTRY=$(echo "$CONFIG" | jq -r '.wifi_country // "FR"')
    SSID=$(echo "$CONFIG" | jq -r '.ssid')
    WIFI_PASSWORD=$(echo "$CONFIG" | jq -r '.password // ""')
    
    log "Application de la configuration"
    
    apply_wifi_country "$WIFI_COUNTRY"
    apply_ssh_config "$SSH_USERNAME" "$SSH_PASSWORD"
    apply_wifi_config "$SSID" "$WIFI_PASSWORD"
    
    touch /etc/runtipi-configured
    
    log "Redémarrage..."
    sleep 3
    reboot
fi
BACKENDEOF

chmod +x /usr/local/bin/wifi-connect-backend.sh

log "✓ Backend créé"

# Script de vérification amélioré
cat > /usr/local/bin/wifi-connect-check.sh << 'EOF'
#!/bin/bash
set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/wifi-connect-check.log
}

log "Vérification connectivité"

if [ -f /etc/runtipi-configured ]; then
    exit 0
fi

log "Attente NetworkManager..."
for i in {1..60}; do
    if systemctl is-active NetworkManager &>/dev/null; then
        log "NetworkManager actif"
        break
    fi
    sleep 1
done

sleep 5

# CORRECTION : Vérifier que Ethernet ou WiFi a une IP (pas juste "UP")
log "Vérification réseau..."
for i in {1..30}; do
    # Vérifier Ethernet
    if ip addr show eth0 2>/dev/null | grep -q "inet "; then
        log "✓ Ethernet configuré"
        touch /etc/runtipi-configured
        exit 0
    fi

    # Vérifier WiFi
    if ip addr show wlan0 2>/dev/null | grep -q "inet "; then
        log "✓ WiFi configuré"
        touch /etc/runtipi-configured
        exit 0
    fi

    sleep 1
done

# Pas de réseau, lancer WiFi-Connect
log "Aucun réseau détecté, lancement WiFi-Connect"
rfkill unblock wifi 2>/dev/null || true
rfkill unblock wlan 2>/dev/null || true

exec /usr/local/bin/wifi-connect \
    --portal-ssid "RuntipiOS-Setup" \
    --portal-interface wlan0 \
    --ui-directory /usr/local/share/wifi-connect/ui
EOF


chmod +x /usr/local/bin/wifi-connect-check.sh

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

log "✓ Script vérification créé"

# Service systemd CORRIGÉ
log "Configuration du service systemd..."
cat > /etc/systemd/system/wifi-connect.service << 'EOF'
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
EOF

systemctl daemon-reload
systemctl enable wifi-connect.service

log "✓ Service configuré"

rm -f /tmp/wifi-connect.tar.gz

log "======================================"
log "Installation terminée ✓"
log "======================================"