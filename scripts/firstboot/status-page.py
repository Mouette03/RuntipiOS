#!/usr/bin/env python3
"""
RuntipiOS Status Page
Displays installation progress and system status
"""

import os
import json
import subprocess
import time
from flask import Flask, render_template_string
import threading

app = Flask(__name__)

STATUS_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RuntipiOS - Installation Status</title>
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
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 800px;
            margin: 40px auto;
            padding: 40px;
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        
        .header h1 {
            color: #667eea;
            font-size: 36px;
            margin-bottom: 10px;
        }
        
        .header p {
            color: #666;
            font-size: 18px;
        }
        
        .status-section {
            margin-bottom: 30px;
        }
        
        .status-section h2 {
            color: #333;
            font-size: 24px;
            margin-bottom: 20px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        
        .progress-bar {
            background: #f0f0f0;
            border-radius: 8px;
            height: 30px;
            overflow: hidden;
            margin: 20px 0;
        }
        
        .progress-fill {
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            height: 100%;
            transition: width 0.5s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: 600;
        }
        
        .step {
            padding: 15px;
            margin: 10px 0;
            border-radius: 8px;
            display: flex;
            align-items: center;
            background: #f8f9ff;
            border-left: 4px solid #e0e0e0;
        }
        
        .step.completed {
            border-left-color: #4caf50;
        }
        
        .step.in-progress {
            border-left-color: #667eea;
            animation: pulse 2s infinite;
        }
        
        .step.pending {
            border-left-color: #e0e0e0;
            opacity: 0.6;
        }
        
        .step-icon {
            font-size: 24px;
            margin-right: 15px;
            min-width: 30px;
        }
        
        .step-text {
            flex: 1;
        }
        
        .step-title {
            font-weight: 600;
            color: #333;
            margin-bottom: 5px;
        }
        
        .step-description {
            font-size: 14px;
            color: #666;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        
        .info-box {
            background: #e8f4ff;
            border: 2px solid #667eea;
            border-radius: 8px;
            padding: 20px;
            margin-top: 30px;
        }
        
        .info-box h3 {
            color: #667eea;
            margin-bottom: 15px;
        }
        
        .info-item {
            margin: 10px 0;
            display: flex;
            align-items: center;
        }
        
        .info-label {
            font-weight: 600;
            color: #333;
            min-width: 120px;
        }
        
        .info-value {
            color: #666;
            font-family: monospace;
        }
        
        .refresh-notice {
            text-align: center;
            color: #666;
            font-size: 14px;
            margin-top: 20px;
        }
        
        .spinner {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid rgba(102, 126, 234, 0.3);
            border-radius: 50%;
            border-top-color: #667eea;
            animation: spin 1s ease-in-out infinite;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
    </style>
    <script>
        // Auto-refresh every 10 seconds
        setTimeout(function() {
            location.reload();
        }, 10000);
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 RuntipiOS Installation</h1>
            <p>Setting up your home server...</p>
        </div>
        
        <div class="status-section">
            <h2>Installation Progress</h2>
            <div class="progress-bar">
                <div class="progress-fill" style="width: {{ progress }}%">
                    {{ progress }}%
                </div>
            </div>
            
            <div class="step {{ 'completed' if step >= 1 else 'in-progress' if step == 0 else 'pending' }}">
                <div class="step-icon">{{ '✅' if step >= 1 else '🔄' if step == 0 else '⏳' }}</div>
                <div class="step-text">
                    <div class="step-title">Network Configuration</div>
                    <div class="step-description">Connecting to WiFi network</div>
                </div>
            </div>
            
            <div class="step {{ 'completed' if step >= 2 else 'in-progress' if step == 1 else 'pending' }}">
                <div class="step-icon">{{ '✅' if step >= 2 else '🔄' if step == 1 else '⏳' }}</div>
                <div class="step-text">
                    <div class="step-title">User Account Creation</div>
                    <div class="step-description">Creating SSH user with sudo privileges</div>
                </div>
            </div>
            
            <div class="step {{ 'completed' if step >= 3 else 'in-progress' if step == 2 else 'pending' }}">
                <div class="step-icon">{{ '✅' if step >= 3 else '🔄' if step == 2 else '⏳' }}</div>
                <div class="step-text">
                    <div class="step-title">Docker Installation</div>
                    <div class="step-description">Installing Docker and Docker Compose</div>
                </div>
            </div>
            
            <div class="step {{ 'completed' if step >= 4 else 'in-progress' if step == 3 else 'pending' }}">
                <div class="step-icon">{{ '✅' if step >= 4 else '🔄' if step == 3 else '⏳' }}</div>
                <div class="step-text">
                    <div class="step-title">Runtipi Installation</div>
                    <div class="step-description">Downloading and configuring Runtipi</div>
                </div>
            </div>
            
            <div class="step {{ 'completed' if step >= 5 else 'in-progress' if step == 4 else 'pending' }}">
                <div class="step-icon">{{ '✅' if step >= 5 else '🔄' if step == 4 else '⏳' }}</div>
                <div class="step-text">
                    <div class="step-title">Starting Services</div>
                    <div class="step-description">Launching Runtipi and enabling services</div>
                </div>
            </div>
        </div>
        
        {% if step >= 5 %}
        <div class="info-box">
            <h3>✅ Installation Complete!</h3>
            <p style="margin-bottom: 15px;">Your RuntipiOS system is now ready to use.</p>
            
            <div class="info-item">
                <div class="info-label">Runtipi URL:</div>
                <div class="info-value">http://{{ ip_address }}</div>
            </div>
            
            <div class="info-item">
                <div class="info-label">SSH Access:</div>
                <div class="info-value">ssh {{ username }}@{{ ip_address }}</div>
            </div>
            
            <p style="margin-top: 20px; font-size: 14px; color: #666;">
                You can now access Runtipi through your web browser or connect via SSH to manage your system.
            </p>
        </div>
        {% else %}
        <div class="refresh-notice">
            <div class="spinner"></div>
            <p>This page will automatically refresh to show the latest status...</p>
        </div>
        {% endif %}
    </div>
</body>
</html>
"""

def get_installation_status():
    """Determine the current installation step"""
    state_file = "/var/lib/runtipios/wifi-connect-state"
    config_file = "/tmp/runtipios-config.json"
    
    # Check state
    if os.path.exists(state_file):
        with open(state_file, 'r') as f:
            state = f.read().strip()
            
        if state == "complete":
            return 5, 100
        elif state == "install":
            # Check if Runtipi is installed
            if os.path.exists("/opt/runtipi"):
                return 4, 80
            else:
                return 3, 60
        elif state == "configure":
            return 2, 40
        elif state == "portal":
            return 1, 20
    
    return 0, 0

def get_system_info():
    """Get system information"""
    try:
        # Get IP address
        result = subprocess.run(['hostname', '-I'], capture_output=True, text=True, timeout=5)
        ip_address = result.stdout.strip().split()[0] if result.stdout else "unknown"
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, IndexError):
        ip_address = "unknown"
    
    # Get username from config
    username = "runtipi"
    config_file = "/tmp/runtipios-config.json"
    if os.path.exists(config_file):
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)
                username = config.get('username', 'runtipi')
        except (IOError, json.JSONDecodeError):
            pass
    
    return {
        'ip_address': ip_address,
        'username': username
    }

@app.route('/')
def status():
    """Display status page"""
    step, progress = get_installation_status()
    system_info = get_system_info()
    
    return render_template_string(
        STATUS_TEMPLATE,
        step=step,
        progress=progress,
        ip_address=system_info['ip_address'],
        username=system_info['username']
    )

def main():
    # Get port from environment variable or default to 8080
    port = int(os.environ.get('STATUS_PAGE_PORT', '8080'))
    # Run Flask app
    app.run(host='0.0.0.0', port=port, debug=False)

if __name__ == '__main__':
    main()
