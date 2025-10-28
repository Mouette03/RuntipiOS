#!/bin/bash
# Script d'installation de Balena WiFi-Connect avec interface personnalisée

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "======================================"
log "Installation de WiFi-Connect avec UI personnalisée"
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

# Créer l'interface HTML personnalisée
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
            
            <!-- Étape 2: Configuration WiFi -->
            <div class="step" data-step="2">
                <div class="info-box">
                    <p id="info-step2">Select your WiFi network and enter the password.</p>
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
                'info-step2': "Select your WiFi network and enter the password.",
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
                'info-step2': "Sélectionnez votre réseau WiFi et entrez le mot de passe.",
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
            
            // Traduire tous les éléments
            Object.keys(translations[lang]).forEach(key => {
                const element = document.getElementById(key);
                if (element) {
                    if (element.tagName === 'INPUT' || element.tagName === 'BUTTON') {
                        if (element.placeholder) element.placeholder = translations[lang][key];
                        if (element.value && key.includes('btn')) element.textContent = translations[lang][key];
                        if (element.textContent && !element.value) element.textContent = translations[lang][key];
                    } else {
                        element.textContent = translations[lang][key];
                    }
                }
            });
        }
        
        function togglePassword(fieldId) {
            const field = document.getElementById(fieldId);
            field.type = field.type === 'password' ? 'text' : 'password';
        }
        
        function nextStep() {
            // Validation
            if (currentStep === 1) {
                const username = document.getElementById('ssh_username').value;
                const password = document.getElementById('ssh_password').value;
                const confirm = document.getElementById('ssh_password_confirm').value;
                
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
                
                // Remplir le résumé
                document.getElementById('review_ssh_username').textContent = 
                    document.getElementById('ssh_username').value;
                document.getElementById('review_ssid').textContent = ssid;
                const wifiPass = document.getElementById('wifi_password').value;
                document.getElementById('review_wifi_password').textContent = 
                    wifiPass ? '••••••••' : '(Open network)';
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
            const btn = document.getElementById('btn-scan');
            btn.disabled = true;
            btn.textContent = '⏳ ' + (currentLang === 'en' ? 'Scanning...' : 'Scan en cours...');
            
            try {
                const response = await fetch('/networks');
                const networks = await response.json();
                
                select.innerHTML = '<option value="">' + 
                    translations[currentLang]['option-select'] + '</option>';
                
                networks.forEach(network => {
                    const option = document.createElement('option');
                    option.value = network.ssid;
                    option.textContent = `${network.ssid} (${network.signal}%)`;
                    select.appendChild(option);
                });
            } catch (error) {
                console.error('Error scanning networks:', error);
            }
            
            btn.disabled = false;
            btn.textContent = translations[currentLang]['btn-scan'];
        }
        
        document.getElementById('setupForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            currentStep = 4;
            updateSteps();
            
            const data = {
                ssh_username: document.getElementById('ssh_username').value,
                ssh_password: document.getElementById('ssh_password').value,
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
                    document.querySelector('[data-step="4"]').innerHTML = `
                        <div class="success">
                            <h3>${translations[currentLang]['success-title']}</h3>
                            <p>${translations[currentLang]['success-text']}</p>
                            <p style="margin-top: 15px;">
                                <strong>http://runtipios.local</strong><br>
                                ssh ${data.ssh_username}@runtipios.local
                            </p>
                        </div>
                    `;
                } else {
                    throw new Error('Connection failed');
                }
            } catch (error) {
                document.querySelector('[data-step="4"]').innerHTML = `
                    <div class="error">
                        <h3>Error</h3>
                        <p>${translations[currentLang]['error-network']}</p>
                    </div>
                    <button type="button" class="btn-primary" onclick="location.reload()" 
                            style="width: 100%; margin-top: 20px;">
                        ${currentLang === 'en' ? 'Try Again' : 'Réessayer'}
                    </button>
                `;
            }
        });
        
        // Scanner les réseaux au chargement
        window.addEventListener('load', () => {
            scanNetworks();
        });
    </script>
</body>
</html>
HTMLEOF

log "✓ Interface HTML créée"

# Créer le script de traitement du backend
cat > /usr/local/bin/wifi-connect-backend.sh << 'BACKENDEOF'
#!/bin/bash
# Backend pour traiter la configuration WiFi-Connect

CONFIG_FILE="/tmp/wifi-connect-config.json"

# Lire la configuration envoyée
read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    fi
}

# Appliquer la configuration SSH
apply_ssh_config() {
    local username=$1
    local password=$2
    
    # Créer l'utilisateur s'il n'existe pas
    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash -G sudo,docker "$username"
    fi
    
    # Définir le mot de passe
    echo "$username:$password" | chpasswd
    
    # Configurer les permissions SSH
    mkdir -p /home/$username/.ssh
    chmod 700 /home/$username/.ssh
    chown -R $username:$username /home/$username/.ssh
}

# Appliquer la configuration WiFi
apply_wifi_config() {
    local ssid=$1
    local password=$2
    
    # Utiliser nmcli pour configurer le WiFi
    if [ -n "$password" ]; then
        nmcli device wifi connect "$ssid" password "$password"
    else
        nmcli device wifi connect "$ssid"
    fi
}

# Point d'entrée principal
if [ "$1" = "apply" ]; then
    CONFIG=$(read_config)
    
    SSH_USERNAME=$(echo "$CONFIG" | jq -r '.ssh_username')
    SSH_PASSWORD=$(echo "$CONFIG" | jq -r '.ssh_password')
    SSID=$(echo "$CONFIG" | jq -r '.ssid')
    WIFI_PASSWORD=$(echo "$CONFIG" | jq -r '.password')
    
    # Appliquer la configuration
    apply_ssh_config "$SSH_USERNAME" "$SSH_PASSWORD"
    apply_wifi_config "$SSID" "$WIFI_PASSWORD"
    
    # Marquer comme configuré
    touch /etc/runtipi-configured
    
    # Redémarrer pour appliquer tous les changements
    sleep 2
    reboot
fi
BACKENDEOF

chmod +x /usr/local/bin/wifi-connect-backend.sh

log "✓ Backend script créé"

# Créer le script de vérification de connectivité
log "Création du script de vérification..."
cat > /usr/local/bin/wifi-connect-check.sh << 'EOF'
#!/bin/bash
# Script de vérification de la connectivité réseau

# Vérifier si le fichier de configuration réseau existe
if [ -f /etc/runtipi-configured ]; then
    # Système déjà configuré, ne pas lancer wifi-connect
    exit 0
fi

# Vérifier la connectivité Ethernet
if ip link show eth0 2>/dev/null | grep -q "state UP"; then
    # Ethernet connecté, marquer comme configuré et ne pas lancer wifi-connect
    touch /etc/runtipi-configured
    exit 0
fi

# Vérifier la connectivité WiFi
if nmcli -t -f GENERAL.STATE dev show wlan0 2>/dev/null | grep -q "100 (connected)"; then
    # WiFi connecté, marquer comme configuré et ne pas lancer wifi-connect
    touch /etc/runtipi-configured
    exit 0
fi

# Pas de connectivité, lancer wifi-connect avec l'UI personnalisée
exec /usr/local/bin/wifi-connect \
    --portal-ssid "RuntipiOS-Setup" \
    --portal-interface wlan0 \
    --ui-directory /usr/local/share/wifi-connect/ui
EOF

chmod +x /usr/local/bin/wifi-connect-check.sh

log "✓ Script de vérification créé"

# Créer le service systemd
log "Configuration du service systemd..."
cat > /etc/systemd/system/wifi-connect.service << 'EOF'
[Unit]
Description=Balena WiFi Connect with Custom UI
After=NetworkManager.service
Wants=NetworkManager.service
Before=runtipi-installer.service

[Service]
Type=simple
ExecStart=/usr/local/bin/wifi-connect-check.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Activer le service
systemctl daemon-reload
systemctl enable wifi-connect.service

log "✓ Service WiFi-Connect configuré et activé"

# Nettoyer
rm -f /tmp/wifi-connect.tar.gz

log "======================================"
log "Installation de WiFi-Connect terminée"
log "======================================"
