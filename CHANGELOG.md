# Changelog

All notable changes to RuntipiOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - Upcoming

### Added
- Initial release of RuntipiOS
- Lightweight Debian Bookworm-based ISO
- Graphical configuration wizard using Tkinter
  - WiFi setup (when ethernet not available)
  - SSH user creation
  - Password configuration
- Text-based fallback installer using dialog/whiptail
- Automatic Runtipi installation on first boot
- Display of Runtipi connection address
- Docker and Docker Compose pre-installed
- NetworkManager for network configuration
- Systemd service for first-boot configuration
- GitHub Actions workflow for automated builds
- Customizable build configuration via YAML
- ISOLINUX and GRUB EFI bootloader support
- Comprehensive documentation and examples
- Local build script for easy ISO generation
- SSH server enabled by default

### Features
- Boots from USB or CD/DVD
- Supports both BIOS and UEFI systems
- Automatic network detection
- User-friendly setup process
- No manual Runtipi installation required
- System ready to use after first boot

[1.0.0]: https://github.com/Mouette03/RuntipiOS/releases/tag/v1.0.0
