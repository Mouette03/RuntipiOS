# RuntipiOS Quick Start Guide

Get up and running with RuntipiOS in minutes!

## What is RuntipiOS?

RuntipiOS is a lightweight, Debian-based operating system that automatically installs and configures [Runtipi](https://github.com/runtipi/runtipi) - a simple home server management system. It features an easy-to-use graphical installer that guides you through WiFi setup, user creation, and system configuration.

## Quick Installation (3 Steps)

### Step 1: Get the ISO

#### Option A: Download from Releases (Recommended)
1. Go to the [Releases page](https://github.com/Mouette03/RuntipiOS/releases)
2. Download the latest `.iso` file
3. Download the `SHA256SUMS` file to verify integrity (optional but recommended)

#### Option B: Build from Source
```bash
git clone https://github.com/Mouette03/RuntipiOS.git
cd RuntipiOS
chmod +x build.sh
./build.sh
```
The ISO will be in the `output/` directory.

### Step 2: Create Bootable Media

#### On Linux
```bash
sudo dd if=RuntipiOS-*.iso of=/dev/sdX bs=4M status=progress && sync
```
Replace `/dev/sdX` with your USB drive (e.g., `/dev/sdb`). Use `lsblk` to find the correct device.

#### On Windows
Use [Rufus](https://rufus.ie/) or [Balena Etcher](https://www.balena.io/etcher/):
1. Insert USB drive
2. Open Rufus/Etcher
3. Select the RuntipiOS ISO
4. Select your USB drive
5. Click "Start" or "Flash"

#### On macOS
```bash
sudo dd if=RuntipiOS-*.iso of=/dev/diskX bs=4m && sync
```
Use `diskutil list` to find the correct disk.

### Step 3: Boot and Install

1. **Insert the bootable USB** into your target machine
2. **Boot from USB** (usually press F12, F2, DEL, or ESC during boot)
3. **Select "RuntipiOS"** from the boot menu
4. **Wait for the system to load** (this may take a minute)
5. **Follow the configuration wizard**:
   
   The graphical wizard will ask you for:
   - **WiFi credentials** (only if no ethernet connection is detected)
   - **Username** for SSH access (default: `runtipi`)
   - **Password** for the user account
   
6. **Wait for Runtipi to install** (this happens automatically)
7. **Note the connection address** displayed on screen

## First Login

### Via SSH
```bash
ssh username@<ip-address>
```
Use the username and password you configured during installation.

### Via Runtipi Web Interface
Open your browser and go to:
```
http://<ip-address>
```
The IP address is displayed on the system console and in the MOTD when you SSH in.

## What Happens After Installation?

1. **Automatic Configuration**: The system automatically:
   - Creates your user account with sudo privileges
   - Configures network (WiFi or Ethernet)
   - Installs Docker and Docker Compose
   - Clones and installs Runtipi
   - Starts Runtipi service
   - Displays connection information

2. **Services Running**:
   - SSH server (for remote access)
   - Docker (for container management)
   - NetworkManager (for network configuration)
   - Runtipi (your home server dashboard)

3. **Access Methods**:
   - **Runtipi Web UI**: `http://<ip-address>`
   - **SSH**: `ssh username@<ip-address>`
   - **Console**: Direct login on the machine

## Common First Tasks

### Check Runtipi Status
```bash
systemctl status runtipi
docker ps
```

### View Installation Logs
```bash
cat /var/log/runtipios-firstboot.log
```

### Restart Runtipi
```bash
cd /opt/runtipi
sudo systemctl restart runtipi
```

### Check Network Configuration
```bash
ip addr
nmcli connection show
```

## Troubleshooting

### Can't connect to WiFi?
```bash
# List available networks
nmcli device wifi list

# Connect to a network
nmcli device wifi connect "SSID" password "password"
```

### Forgot the IP address?
```bash
hostname -I
# or
ip addr show
```

### Runtipi not accessible?
```bash
# Check if Runtipi is running
systemctl status runtipi
docker ps

# Restart Runtipi
cd /opt/runtipi
./scripts/stop.sh
./scripts/start.sh
```

### SSH not working?
```bash
# Check SSH service
systemctl status ssh

# Restart SSH service
sudo systemctl restart ssh
```

## Next Steps

1. **Explore Runtipi**: 
   - Access the web interface
   - Install your first app
   - Configure your home server

2. **Customize System**:
   - Install additional packages
   - Configure firewall
   - Set up backups

3. **Secure Your System**:
   - Change default passwords
   - Configure SSH keys
   - Update the system: `sudo apt update && sudo apt upgrade`

## Support

- **RuntipiOS Issues**: [GitHub Issues](https://github.com/Mouette03/RuntipiOS/issues)
- **Runtipi Documentation**: [Runtipi Docs](https://github.com/runtipi/runtipi)
- **Community Support**: Check the Runtipi community forums

## System Requirements

**Minimum:**
- x86_64 compatible processor
- 2GB RAM
- 10GB disk space
- Network connection (Ethernet or WiFi)

**Recommended:**
- Dual-core processor
- 4GB RAM
- 20GB+ disk space
- Gigabit Ethernet

---

**Enjoy your new RuntipiOS system!** 🚀

For more detailed information, see the [README](README.md) and [TESTING](TESTING.md) documentation.
