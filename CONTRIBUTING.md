# Contributing to RuntipiOS

Thank you for your interest in contributing to RuntipiOS!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Mouette03/RuntipiOS.git
   cd RuntipiOS
   ```

2. Install Docker if you haven't already:
   - [Docker installation guide](https://docs.docker.com/get-docker/)

3. Make sure you have at least 4GB of free disk space

## Making Changes

### Modifying the Build Configuration

Edit `build-config.yml` to:
- Change the base distribution or release
- Add or remove packages
- Modify ISO name/version
- Adjust Runtipi settings

### Modifying Scripts

Scripts are located in the `scripts/` directory:
- `build-iso.sh` - Main ISO building logic
- `chroot-setup.sh` - System configuration inside chroot
- `setup-bootloader.sh` - Bootloader configuration
- `firstboot/` - First boot configuration scripts

### Testing Your Changes

1. Build the ISO locally:
   ```bash
   ./build.sh
   ```

2. Test in a VM:
   - Use VirtualBox, VMware, or QEMU
   - Boot from the ISO
   - Verify the installation wizard works
   - Check that Runtipi installs correctly

### Code Style

- Shell scripts: Follow bash best practices
- Python: PEP 8 style guide
- Use descriptive variable names
- Add comments for complex logic

## Submitting Changes

1. Fork the repository
2. Create a new branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test thoroughly
5. Commit with descriptive messages
6. Push to your fork
7. Create a Pull Request

## Pull Request Guidelines

- Describe what your PR does
- Include test results or screenshots
- Reference any related issues
- Keep changes focused and atomic

## Reporting Issues

When reporting issues, please include:
- RuntipiOS version
- Steps to reproduce
- Expected vs actual behavior
- System specifications
- Relevant log files (`/var/log/runtipios-firstboot.log`)

## Questions?

Feel free to open an issue for questions or discussions!
