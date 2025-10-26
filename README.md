# RuntipiOS
Runtipi System OS

A lightweight Debian-based operating system with automatic Runtipi installation and graphical configuration.

## Features

- **Lightweight**: Based on Debian Bookworm, minimal installation without UI
- **Graphical Configuration**: Easy-to-use setup wizard that asks for:
  - WiFi configuration (if no ethernet connection)
  - SSH user creation
  - Password setup
- **Automatic Runtipi Installation**: Runtipi is automatically installed and started
- **Connection Display**: The system displays the Runtipi connection address after installation
- **GitHub Actions**: Automated builds and releases via GitHub workflows
- **Customizable**: Easy to modify via `build-config.yml`

## Quick Start

### Building the ISO

#### Using the build script (recommended):
```bash
chmod +x build.sh
./build.sh
```

#### Manual Docker build:
```bash
docker build -t runtipios-builder:latest .
docker run --rm --privileged -v $(pwd)/output:/build/output runtipios-builder:latest
```

The ISO file will be created in the `output/` directory.

### Installing RuntipiOS

1. Download or build the ISO file
2. Write the ISO to a USB drive:
   ```bash
   sudo dd if=output/RuntipiOS-*.iso of=/dev/sdX bs=4M status=progress && sync
   ```
   Replace `/dev/sdX` with your USB drive (e.g., `/dev/sdb`)

3. Boot from the USB drive
4. Follow the graphical configuration wizard:
   - Configure WiFi (if needed)
   - Create SSH user
   - Set password

5. The system will automatically install Runtipi and display the connection address

### Accessing Runtipi

After installation, Runtipi will be accessible at:
- `http://<your-ip-address>`
- `http://localhost` (if accessing from the machine itself)

You can also SSH into the system using the credentials you configured.

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
│       ├── gui-installer.py # Graphical configuration wizard
│       ├── text-installer.sh # Text-based configuration
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
