# RuntipiOS
Runtipi System OS

A lightweight Debian-based operating system with automatic Runtipi installation and captive portal WiFi configuration.

## Features

- **Lightweight**: Based on Debian Bookworm, minimal installation without UI
- **WiFi Connect**: Captive portal for easy WiFi configuration using Balena-inspired technology
  - Automatic network detection
  - WiFi captive portal when no connection is available
  - Modern web-based configuration interface
  - Intelligent mode switching between setup and operational modes
- **Automatic Runtipi Installation**: Runtipi is automatically installed and started
- **Connection Display**: The system displays the Runtipi connection address after installation
- **GitHub Actions**: Automated builds and releases via GitHub workflows
- **Customizable**: Easy to modify via `build-config.yml`

## Quick Start


### Construction de l'image Raspberry Pi (arm64)

#### Avec le script de build (recommandé) :
```bash
chmod +x build.sh
./build.sh
```

#### Build Docker manuel :
```bash
docker build -t runtipios-builder:latest .
docker run --rm --privileged -v $(pwd)/output:/build/output runtipios-builder:latest /bin/bash -lc "/build/scripts/build-pi-image.sh"
```

L'image Pi sera créée dans le dossier `output/`.

### Installation sur Raspberry Pi

1. Téléchargez ou construisez l'image Pi
2. Écrivez l'image sur une carte SD :
  ```bash
  sudo dd if=output/RuntipiOS-*.img of=/dev/sdX bs=4M status=progress && sync
  ```
  Remplacez `/dev/sdX` par votre carte SD (ex : `/dev/sdb`)

3. Insérez la carte SD dans le Raspberry Pi et démarrez
4. Le système :
  - Détecte la connectivité réseau
  - Si aucun réseau, démarre le portail WiFi
  - Connectez-vous au WiFi "RuntipiOS-Setup"
  - Ouvrez un navigateur sur http://192.168.42.1
  - Configurez le WiFi et l'utilisateur SSH via l'interface web
  - Installe et configure automatiquement Runtipi

5. L'adresse de connexion Runtipi s'affichera à la fin

### Accès à Runtipi

Après installation, Runtipi est accessible à :
- `http://<adresse-ip-local>`
- `http://localhost` (if accessing from the machine itself)

You can also SSH into the system using the credentials you configured.

## WiFi Connect Configuration

RuntipiOS uses a captive portal system inspired by Balena WiFi Connect for easy network configuration.

### How It Works

1. **Network Detection**: On first boot, the system automatically detects if a network connection is available
2. **Captive Portal Mode**: If no connection is found, the system creates a WiFi access point named "RuntipiOS-Setup"
3. **Web Configuration**: Connect to the access point and a captive portal opens automatically at http://192.168.42.1
4. **Setup Process**: Configure your WiFi network, SSH credentials, and other settings through the web interface
5. **Installation Status**: After configuration, a status page shows real-time installation progress at http://<ip>:8080
6. **Automatic Installation**: The system automatically connects to your WiFi and installs Runtipi
7. **Operational Mode**: After setup, the system switches to normal operational mode

### Customizing WiFi Connect

You can customize the captive portal settings in `build-config.yml`:

```yaml
wifi_connect:
  enabled: true
  portal_ssid: "RuntipiOS-Setup"      # Name of the setup WiFi network
  portal_password: ""                  # Leave empty for open network
  portal_interface: wlan0              # WiFi interface to use
  portal_address: 192.168.42.1        # IP address of the portal
  portal_dhcp_range: "192.168.42.10,192.168.42.100"  # DHCP range
```

### Manual Configuration

If you need to reconfigure the network after installation, you can restart the WiFi Connect service:

```bash
sudo systemctl restart wifi-connect.service
```

## Configuration

### Customizing the Build

Edit `build-config.yml` to customize:
- Base distribution and release
- ISO name and version
- Packages to include
- Runtipi configuration
- First-boot settings

Example:
```yaml
iso:
  name: RuntipiOS
  version: 1.0.0
  label: RUNTIPIOS

packages:
  - linux-image-amd64
  - network-manager
  - openssh-server
  - docker.io
  # Add more packages here
```

### GitHub Actions Workflow

The repository includes a GitHub Actions workflow that automatically builds and releases the ISO.

#### Triggering a Release

1. **Automatic release on tag**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Manual workflow dispatch**:
   - Go to Actions tab in GitHub
   - Select "Build and Release RuntipiOS"
   - Click "Run workflow"
   - Enter a version tag (optional)

The workflow will:
- Build the Docker image
- Create the ISO
- Generate checksums
- Create a GitHub release (for tags) or upload artifacts (for manual runs)

## Project Structure

```
RuntipiOS/
├── build-config.yml          # Build configuration
├── Dockerfile                # Docker build environment
├── build.sh                  # Local build script
├── scripts/
│   ├── build-iso.sh         # Main ISO building script
│   ├── parse-config.py      # Config parser
│   ├── chroot-setup.sh      # Chroot environment setup
│   ├── setup-bootloader.sh  # Bootloader configuration
│   └── firstboot/           # First boot scripts
│       ├── firstboot.sh     # Main first-boot script
│       ├── wifi-connect-orchestrator.sh  # WiFi Connect orchestration
│       ├── wifi-connect-portal.py        # Captive portal web interface
│       ├── wifi-connect.service          # systemd service for WiFi Connect
│       ├── status-page.py                # Installation status page
│       ├── gui-installer.py # Graphical configuration wizard (legacy)
│       ├── text-installer.sh # Text-based configuration (legacy)
│       └── install-runtipi.sh # Runtipi installation
└── .github/
    └── workflows/
        └── build-release.yml # GitHub Actions workflow
```

## Requirements

### For Building
- Docker
- At least 4GB free disk space
- Privileged Docker access (for building the ISO)

### For Running
- x86_64 compatible system
- Minimum 2GB RAM
- 10GB free disk space
- Network connection (ethernet or WiFi)

## Troubleshooting

### Build Issues

**Problem**: Docker build fails with permission errors
**Solution**: Make sure Docker has privileged access:
```bash
docker run --rm --privileged ...
```

**Problem**: ISO build runs out of space
**Solution**: Clean up Docker and ensure at least 4GB free space

### Installation Issues

**Problem**: WiFi configuration doesn't work
**Solution**: Check if your WiFi adapter is supported by Debian. You may need non-free firmware.

**Problem**: Runtipi doesn't start
**Solution**: Check the logs at `/var/log/runtipios-firstboot.log`

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

See [LICENSE](LICENSE) file for details.

## Related Projects

- [Runtipi](https://github.com/runtipi/runtipi) - The main Runtipi project
- [Debian](https://www.debian.org/) - The base operating system

## Support

For issues related to:
- **RuntipiOS build/installation**: Open an issue in this repository
- **Runtipi functionality**: Check the [Runtipi repository](https://github.com/runtipi/runtipi)
