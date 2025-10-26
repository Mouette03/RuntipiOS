#!/usr/bin/env python3
"""
WiFi Connect Portal for RuntipiOS
Custom web interface for WiFi configuration with Runtipi-specific parameters
"""

import os
import json
import subprocess
from flask import Flask, render_template_string, request, jsonify
import netifaces

app = Flask(__name__)

CONFIG_FILE = "/tmp/runtipios-config.json"

# HTML Template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RuntipiOS WiFi Setup</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 500px;
            width: 100%;
            padding: 40px;
        }
        
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        
        .logo h1 {
            color: #667eea;
            font-size: 32px;
            font-weight: 700;
            margin-bottom: 10px;
        }
        
        .logo p {
            color: #666;
            font-size: 16px;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            color: #333;
            font-weight: 600;
            margin-bottom: 8px;
            font-size: 14px;
        }
        
        input, select {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        
        input:focus, select:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .btn {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
        
        .btn:active {
            transform: translateY(0);
        }
        
        .btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        
        .message {
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: none;
        }
        
        .message.error {
            background: #fee;
            color: #c33;
            border: 1px solid #fcc;
        }
        
        .message.success {
            background: #efe;
            color: #3c3;
            border: 1px solid #cfc;
        }
        
        .message.info {
            background: #eef;
            color: #33c;
            border: 1px solid #ccf;
        }
        
        .loading {
            text-align: center;
            padding: 20px;
            display: none;
        }
        
        .spinner {
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 10px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .network-item {
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            margin-bottom: 10px;
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .network-item:hover {
            border-color: #667eea;
            background: #f8f9ff;
        }
        
        .network-item.selected {
            border-color: #667eea;
            background: #f0f4ff;
        }
        
        .network-name {
            font-weight: 600;
            color: #333;
        }
        
        .network-signal {
            font-size: 12px;
            color: #666;
        }
        
        .help-text {
            font-size: 12px;
            color: #666;
            margin-top: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <h1>🚀 RuntipiOS</h1>
            <p>WiFi Configuration</p>
        </div>
        
        <div id="message" class="message"></div>
        
        <form id="configForm">
            <div class="form-group">
                <label for="wifi_ssid">WiFi Network</label>
                <select id="wifi_ssid" name="wifi_ssid" required>
                    <option value="">Scanning for networks...</option>
                </select>
                <div class="help-text">Select your WiFi network from the list</div>
            </div>
            
            <div class="form-group">
                <label for="wifi_password">WiFi Password</label>
                <input type="password" id="wifi_password" name="wifi_password" 
                       placeholder="Enter WiFi password" required>
            </div>
            
            <div class="form-group">
                <label for="ssh_username">SSH Username</label>
                <input type="text" id="ssh_username" name="ssh_username" 
                       value="runtipi" placeholder="runtipi" required>
                <div class="help-text">Username for SSH access to the system</div>
            </div>
            
            <div class="form-group">
                <label for="ssh_password">SSH Password</label>
                <input type="password" id="ssh_password" name="ssh_password" 
                       placeholder="Enter password" required minlength="6">
                <div class="help-text">Minimum 6 characters</div>
            </div>
            
            <div class="form-group">
                <label for="ssh_password_confirm">Confirm Password</label>
                <input type="password" id="ssh_password_confirm" name="ssh_password_confirm" 
                       placeholder="Confirm password" required minlength="6">
            </div>
            
            <button type="submit" class="btn" id="submitBtn">
                Configure RuntipiOS
            </button>
        </form>
        
        <div class="loading" id="loading">
            <div class="spinner"></div>
            <p>Configuring your system...</p>
        </div>
    </div>
    
    <script>
        // Scan for WiFi networks
        function scanNetworks() {
            fetch('/api/scan')
                .then(response => response.json())
                .then(data => {
                    const select = document.getElementById('wifi_ssid');
                    select.innerHTML = '<option value="">Select a network...</option>';
                    
                    if (data.networks && data.networks.length > 0) {
                        data.networks.forEach(network => {
                            const option = document.createElement('option');
                            option.value = network.ssid;
                            option.textContent = `${network.ssid} (${network.signal}%)`;
                            select.appendChild(option);
                        });
                    } else {
                        select.innerHTML = '<option value="">No networks found</option>';
                    }
                })
                .catch(error => {
                    console.error('Error scanning networks:', error);
                    showMessage('Failed to scan for networks. You can enter the SSID manually.', 'error');
                });
        }
        
        function showMessage(text, type) {
            const messageDiv = document.getElementById('message');
            messageDiv.textContent = text;
            messageDiv.className = 'message ' + type;
            messageDiv.style.display = 'block';
        }
        
        function hideMessage() {
            const messageDiv = document.getElementById('message');
            messageDiv.style.display = 'none';
        }
        
        // Form submission
        document.getElementById('configForm').addEventListener('submit', function(e) {
            e.preventDefault();
            hideMessage();
            
            const formData = new FormData(e.target);
            const data = {};
            formData.forEach((value, key) => data[key] = value);
            
            // Validate passwords match
            if (data.ssh_password !== data.ssh_password_confirm) {
                showMessage('Passwords do not match!', 'error');
                return;
            }
            
            // Remove confirm password from submission
            delete data.ssh_password_confirm;
            
            // Show loading
            document.getElementById('configForm').style.display = 'none';
            document.getElementById('loading').style.display = 'block';
            
            // Submit configuration
            fetch('/api/configure', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data)
            })
            .then(response => response.json())
            .then(result => {
                if (result.success) {
                    showMessage('Configuration saved! Your system is now being configured. This page will close automatically.', 'success');
                    setTimeout(() => {
                        window.location.href = '/success';
                    }, 3000);
                } else {
                    document.getElementById('configForm').style.display = 'block';
                    document.getElementById('loading').style.display = 'none';
                    showMessage('Configuration failed: ' + result.error, 'error');
                }
            })
            .catch(error => {
                document.getElementById('configForm').style.display = 'block';
                document.getElementById('loading').style.display = 'none';
                showMessage('Failed to save configuration: ' + error, 'error');
            });
        });
        
        // Scan networks on page load
        scanNetworks();
    </script>
</body>
</html>
"""

SUCCESS_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RuntipiOS - Configuration Complete</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 600px;
            width: 100%;
            padding: 40px;
            text-align: center;
        }
        
        .success-icon {
            font-size: 64px;
            margin-bottom: 20px;
        }
        
        h1 {
            color: #667eea;
            font-size: 32px;
            margin-bottom: 20px;
        }
        
        p {
            color: #666;
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 30px;
        }
        
        .info-box {
            background: #f8f9ff;
            border: 2px solid #667eea;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
        }
        
        .info-box h3 {
            color: #667eea;
            margin-bottom: 10px;
        }
        
        .info-box p {
            margin-bottom: 10px;
        }
        
        .code {
            background: #f0f0f0;
            padding: 10px;
            border-radius: 4px;
            font-family: monospace;
            display: block;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success-icon">✅</div>
        <h1>Configuration Complete!</h1>
        <p>Your RuntipiOS system is now being configured. The installation process includes:</p>
        
        <div class="info-box">
            <h3>What's happening now:</h3>
            <p>1. Connecting to your WiFi network</p>
            <p>2. Creating your user account</p>
            <p>3. Installing Docker and dependencies</p>
            <p>4. Installing and configuring Runtipi</p>
            <p>5. Starting services</p>
        </div>
        
        <div class="info-box">
            <h3>Next Steps:</h3>
            <p>Once installation is complete (5-10 minutes), you can access:</p>
            <p><strong>Runtipi Web Interface:</strong> http://&lt;your-ip&gt;</p>
            <p><strong>SSH Access:</strong> ssh &lt;username&gt;@&lt;your-ip&gt;</p>
        </div>
        
        <p>This portal will close automatically. Please wait for the system to complete the installation.</p>
    </div>
</body>
</html>
"""

@app.route('/')
def index():
    """Serve the main configuration page"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/success')
def success():
    """Serve the success page"""
    return render_template_string(SUCCESS_TEMPLATE)

@app.route('/api/scan')
def scan_networks():
    """Scan for available WiFi networks"""
    try:
        # Use nmcli to scan for networks
        result = subprocess.run(
            ['nmcli', '-t', '-f', 'SSID,SIGNAL', 'device', 'wifi', 'list'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        networks = []
        for line in result.stdout.strip().split('\n'):
            if line and ':' in line:
                parts = line.split(':')
                if len(parts) >= 2:
                    ssid = parts[0].strip()
                    signal = parts[1].strip()
                    if ssid and ssid != '--':
                        networks.append({
                            'ssid': ssid,
                            'signal': signal
                        })
        
        # Remove duplicates and sort by signal strength
        seen = set()
        unique_networks = []
        for net in networks:
            if net['ssid'] not in seen:
                seen.add(net['ssid'])
                unique_networks.append(net)
        
        unique_networks.sort(key=lambda x: int(x['signal']), reverse=True)
        
        return jsonify({'success': True, 'networks': unique_networks})
    except Exception:
        # Don't expose internal error details to users
        return jsonify({'success': False, 'error': 'Failed to scan for networks'})

@app.route('/api/configure', methods=['POST'])
def configure():
    """Save configuration and trigger installation"""
    try:
        config = request.get_json()
        
        # Validate required fields
        required_fields = ['wifi_ssid', 'wifi_password', 'ssh_username', 'ssh_password']
        for field in required_fields:
            if field not in config or not config[field]:
                return jsonify({'success': False, 'error': f'Missing required field: {field}'})
        
        # Save configuration
        with open(CONFIG_FILE, 'w') as f:
            json.dump({
                'username': config['ssh_username'],
                'password': config['ssh_password'],
                'wifi_ssid': config['wifi_ssid'],
                'wifi_password': config['wifi_password']
            }, f)
        
        return jsonify({'success': True})
    except Exception:
        # Don't expose internal error details to users
        return jsonify({'success': False, 'error': 'Failed to save configuration'})

def main():
    # Run Flask app
    app.run(host='0.0.0.0', port=80, debug=False)

if __name__ == '__main__':
    main()
