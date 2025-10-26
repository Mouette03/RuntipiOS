# Testing Guide for RuntipiOS

This guide explains how to test RuntipiOS in different environments.

## Prerequisites

- VirtualBox, VMware, or QEMU installed
- At least 2GB RAM allocated to the VM
- 10GB disk space for the VM
- Built ISO file (see README.md for building instructions)

## Testing in VirtualBox

### Setup

1. Create a new VM:
   - Name: RuntipiOS-Test
   - Type: Linux
   - Version: Debian (64-bit)
   - Memory: 2048 MB (minimum)
   - Create a virtual hard disk (10 GB minimum)

2. Configure VM settings:
   - System > Motherboard: Enable EFI (optional, for UEFI testing)
   - Storage: Attach the RuntipiOS ISO to the IDE Controller
   - Network: Bridge Adapter (for network testing)

3. Start the VM

### Testing Checklist

#### Boot Test
- [ ] VM boots from ISO successfully
- [ ] Boot menu appears (ISOLINUX/GRUB)
- [ ] System loads without errors
- [ ] Login prompt appears

#### Network Detection
- [ ] System detects ethernet connection (if using bridge adapter)
- [ ] Or detects WiFi adapter (if configured)

#### Configuration Wizard
- [ ] Graphical installer launches (if running in graphical mode)
- [ ] OR text installer launches (if in text mode)
- [ ] WiFi configuration appears if no ethernet detected
- [ ] Username field accepts input
- [ ] Password fields accept input
- [ ] Password confirmation validates correctly
- [ ] Configuration completes without errors

#### First Boot
- [ ] System applies configuration
- [ ] User is created successfully
- [ ] Network is configured (ethernet or WiFi)
- [ ] Runtipi installation begins
- [ ] Runtipi installation completes

#### Runtipi Verification
- [ ] Runtipi service is running: `systemctl status runtipi`
- [ ] Docker containers are running: `docker ps`
- [ ] Runtipi is accessible at displayed IP address
- [ ] Web interface loads successfully

#### SSH Access
- [ ] Can SSH to the system using configured credentials
- [ ] User has sudo access
- [ ] User is in docker group

#### System Verification
- [ ] `/var/lib/runtipios/configured` flag exists
- [ ] Service doesn't run on subsequent boots
- [ ] MOTD displays Runtipi information
- [ ] Logs available at `/var/log/runtipios-firstboot.log`

## Testing in QEMU

```bash
# For BIOS boot
qemu-system-x86_64 \
  -m 2048 \
  -cdrom output/RuntipiOS-1.0.0-amd64.iso \
  -boot d \
  -enable-kvm

# For UEFI boot
qemu-system-x86_64 \
  -m 2048 \
  -cdrom output/RuntipiOS-1.0.0-amd64.iso \
  -boot d \
  -enable-kvm \
  -bios /usr/share/ovmf/OVMF.fd
```

## Testing in VMware

1. Create a new VM with similar specifications to VirtualBox
2. Attach the ISO file
3. Follow the same testing checklist

## Physical Hardware Testing

### Creating Bootable USB

```bash
# On Linux
sudo dd if=output/RuntipiOS-1.0.0-amd64.iso of=/dev/sdX bs=4M status=progress && sync

# On macOS
sudo dd if=output/RuntipiOS-1.0.0-amd64.iso of=/dev/diskX bs=4m && sync

# On Windows
# Use Rufus or Balena Etcher
```

### Testing on Hardware
- Boot from USB drive
- Test WiFi with actual WiFi adapter
- Verify ethernet detection
- Test on both BIOS and UEFI systems

## Automated Testing

Currently, there is no automated testing suite. Future improvements could include:
- Packer scripts for automated VM testing
- Selenium/Playwright for UI testing
- Shell script tests for system verification

## Known Limitations

1. **WiFi Firmware**: Some WiFi adapters require non-free firmware that may not be included in the base image
2. **Graphical Mode**: The graphical installer requires X11, which may not be available in all environments
3. **Resource Requirements**: Runtipi requires adequate resources to run properly

## Troubleshooting Tests

### If the graphical installer doesn't appear:
- Check if DISPLAY variable is set
- Verify X11 is available
- System should fall back to text installer

### If WiFi configuration fails:
- Check WiFi adapter compatibility
- Verify NetworkManager is running: `systemctl status NetworkManager`
- Check logs: `/var/log/runtipios-firstboot.log`

### If Runtipi installation fails:
- Check internet connectivity
- Verify Docker is running: `systemctl status docker`
- Check disk space: `df -h`
- Review installation logs

### If SSH doesn't work:
- Verify SSH service is running: `systemctl status ssh`
- Check firewall settings
- Verify user was created: `id username`

## Reporting Test Results

When reporting test results, please include:
- ISO version tested
- Testing environment (VirtualBox/VMware/QEMU/Physical)
- Host OS and version
- Hardware specifications
- Whether the test passed or failed
- Any error messages or logs
- Screenshots if applicable

## Test Report Template

```markdown
## Test Report

**ISO Version**: RuntipiOS-1.0.0-amd64
**Date**: YYYY-MM-DD
**Tester**: Your Name
**Environment**: VirtualBox 7.0 on Ubuntu 22.04

### Boot Test
- Status: ✅ Pass / ❌ Fail
- Notes: 

### Network Configuration
- Status: ✅ Pass / ❌ Fail
- Notes:

### Configuration Wizard
- Status: ✅ Pass / ❌ Fail
- Notes:

### Runtipi Installation
- Status: ✅ Pass / ❌ Fail
- Notes:

### SSH Access
- Status: ✅ Pass / ❌ Fail
- Notes:

### Overall Result
- Status: ✅ Pass / ❌ Fail
- Additional Notes:
```
