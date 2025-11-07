# Arch Linux ARM + Omarchy Automation for Parallels Desktop

Automated installation scripts for deploying Omarchy on Arch Linux ARM using Parallels Desktop on Apple Silicon Macs (tested on MBP M4 Max).

## ⚠️ Security Notice

**IMPORTANT**: This repository contains automation scripts with default credentials for LOCAL VM testing. Before use:

1. **Review and change the default root password** in `Omarchy-Arm.sh` (line 6: `ROOT_PASSWORD="root"`)
2. These scripts are designed for **local development VMs only** - not production systems
3. Change passwords immediately after installation
4. See [SECURITY.md](SECURITY.md) for detailed security recommendations

**The default credentials are intentional for automation purposes and are clearly documented for user customization.**

## Overview

This repository automates the complete workflow from downloading the Archboot ISO to installing a fully configured Arch Linux ARM system ready for Omarchy deployment. The process is streamlined through a series of bash scripts that handle VM creation, system installation, and post-configuration.

## Related Resources

- **Archboot ARM ISO**: https://release.archboot.com/aarch64/latest/iso/
- **Omarchy ARM PR**: https://github.com/basecamp/omarchy/pull/1897

## Prerequisites

- **macOS** with Apple Silicon (M1/M2/M3/M4)
- **Parallels Desktop** installed
- **aria2c** for fast downloads: `brew install aria2`
- **GPG** for signature verification: `brew install gnupg`
- **Ghostty terminal** (optional, for terminal compatibility setup)

## Quick Start

### 1. Download the Latest Archboot ISO

```bash
./get_latest_version.sh
```

This script will:
- Fetch the latest Archboot ARM ISO from the official release page
- Present three ISO options:
  - **local**: Full local packages (largest, fastest installation, works offline)
  - **latest**: Latest packages (smallest, requires internet)
  - **base**: Base packages (medium size, requires internet)
- Download and verify the ISO signature using GPG
- Save the ISO to `~/Downloads/`

**Recommended**: Choose option 1 (local) for the fastest installation and offline capability.

### 2. Configure Your Preferences

```bash
vim config.sh
```

Edit the following variables to suit your needs:

```bash
# VM Configuration
VM_NAME="omarchy3"              # Change VM name if desired
SSH_PORT="11838"                # Custom SSH port (not 22) default Archboot ISO

# Installation Script
INSTALL_SCRIPT="Omarchy-Arm.sh" # Don't change unless using custom script
```

#### ISO Selection Options

The script supports three modes for selecting which ISO to use:

**Option 1: Auto mode (Default)** - Uses the latest ISO:
```bash
# No configuration needed - this is the default
./ArchAuto.sh
```

**Option 2: Interactive mode** - Choose from available ISOs:
```bash
# Run the interactive selector
ISO_SELECT_MODE=interactive ./ArchAuto.sh

# Or use the helper script
./select-iso.sh
```

**Option 3: Manual mode** - Specify a specific ISO:
```bash
# Edit config.sh and set:
ISO_SELECT_MODE="manual"
ISO_PATH="$HOME/Downloads/archboot-2025.11.03-02.26-6.17.7-1-aarch64-ARCH-local-aarch64.iso"
```

**Tip**: If you have a known working ISO (e.g., from Nov 3), use manual mode to ensure consistent installations.

**Note**: If you need to customize the Arch installation itself, edit `Omarchy-Arm.sh`:

```bash
# Inside Omarchy-Arm.sh (lines 5-11)
HOSTNAME="ArchLinux"            # System hostname
ROOT_PASSWORD="root"            # Root password (change for security!)
TIMEZONE="Asia/Jakarta"         # Your timezone
LOCALE="en_US.UTF-8"           # System locale
DISK_DEFAULT="/dev/sda"        # Default disk (auto-detected)
EFI_SIZE="512MiB"              # EFI partition size
BOOT_SIZE="512MiB"             # Boot partition size
```

### 3. Create and Start the VM

```bash
./ArchAuto.sh
```

This script will:
- Delete any existing VM with the same name (clean slate)
- Create a new Parallels VM with:
  - 16GB RAM
  - 4 CPU cores
  - 96GB disk (expandable)
- Attach the Archboot ISO
- Display on-screen instructions for booting

**Follow the on-screen prompts after running the script:**

1. **Start the VM** in Parallels Desktop
2. When Archboot boots:
   - Press `ENTER` at the boot menu
   - Switch to **Online Mode**: `YES`
   - Update Archboot Environment: `NO`
   - Select **Launcher Menu** → **Exit**
   - Select **Exit Menu** → **1 Exit Program**

3. **In the VM console**, configure SSH access:

```bash
# Edit SSH configuration
vim /etc/ssh/sshd_config
# Set these values:
#   PermitRootLogin yes
#   PasswordAuthentication yes

# Restart SSH
systemctl restart sshd

# Set root password
passwd
```

### 4. Transfer Installation Scripts to VM

```bash
./cpscript.sh
```

This script will:
- Get the VM's IP address automatically
- Copy your SSH public key to the VM for passwordless login
- Configure Ghostty terminal compatibility (if using Ghostty)
- Transfer `Omarchy-Arm.sh` installation script to `/tmp/` on the VM
- Set execute permissions on the script
- Display the SSH command to connect

**Output example:**
```
ssh -p 11838 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@10.211.55.X
run /tmp/Omarchy-Arm.sh
after reboot check the vm IP and ssh
```

### 5. Install Arch Linux ARM

SSH into the VM using the command provided by `cpscript.sh`:

```bash
ssh -p 11838 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@<VM_IP>
```

Then run the installation script:

```bash
/tmp/Omarchy-Arm.sh
```

**⏱️ Note**: This script will take 15-30 minutes to complete depending on your internet speed and ISO variant. Sit back and relax while it installs the base system, configures GRUB, and sets up the environment.

**What this script does:**

1. **Pre-installation**:
   - Checks internet connectivity
   - Attempts to use local ISO packages for faster installation
   - Installs required tools (gdisk, parted, vim, etc.)

2. **Disk partitioning** (GPT layout):
   - P1: ESP (EFI System Partition) - 512MiB FAT32 at `/efi`
   - P2: XBOOTLDR partition - 512MiB FAT32 at `/boot`
   - P3: Root partition - remaining space ext4 at `/`

3. **Base system installation**:
   - Installs base Arch ARM with kernel and firmware
   - Installs GRUB bootloader for ARM64 EFI
   - Installs NetworkManager, SSH, development tools

4. **System configuration** (in chroot):
   - Sets timezone, locale, hostname
   - Configures root password
   - Sets up SSH on port 11838 with root login enabled
   - Configures firewall to allow SSH access (ports 11838 and 22)
   - Installs and configures GRUB with custom config
   - Creates pacman hook for automatic GRUB updates
   - Sets up Arch Linux ARM keyring
   - Creates persistent bash history with helpful commands

5. **Finalization**:
   - Generates fstab
   - Unmounts partitions
   - Prompts to disconnect ISO and reboot

**Important**: When prompted "Type 'YES' to continue", type exactly `YES` (uppercase).

After the script completes, **disconnect the ISO** in Parallels before rebooting:
- Parallels → Devices → CD/DVD → Disconnect

Then confirm reboot by typing `YES`.

### 6. Post-Installation (Optional)

After the VM reboots into the new Arch Linux system, you can use the login helper:

```bash
./loginvm.sh
```

This simple script configures Ghostty terminal compatibility for the installed system.

Alternatively, SSH manually:

```bash
# Get the new IP (may have changed after reboot)
prlctl list -i omarchy3 | grep "IP"

# Connect
ssh -p 11838 root@<NEW_IP>
```

### 7. Install Omarchy

Once logged into the new Arch Linux system, install Omarchy:

```bash
# Pre-populated in your bash history - just press UP arrow!
wget -qO- https://raw.githubusercontent.com/jondkinney/armarchy/amarchy-3-x/boot.sh | \
  OMARCHY_REPO=jondkinney/armarchy OMARCHY_REF=amarchy-3-x bash
```

Or for the beta version:

```bash
wget -qO- https://raw.githubusercontent.com/jondkinney/armarchy/amarchy-3-x/boot.sh | \
  OMARCHY_REPO=jondkinney/armarchy OMARCHY_REF=amarchy-3-x-beta bash
```

## Script Reference

### `get_latest_version.sh`

Downloads the latest Archboot ISO with signature verification.

**Features**:
- Auto-detects latest version from Archboot release page
- Offers three ISO variants:
  - **local**: Largest, fastest install, works offline
  - **latest**: Smallest, requires internet
  - **base**: Medium size, requires internet
- GPG signature verification for security

**Requirements**: `aria2c`, `gpg`, `curl`

### `config.sh`

Centralized configuration file sourced by all other scripts.

**Key variables**:
- `VM_NAME`: Parallels VM name
- `SSH_PORT`: SSH port (11838)
- `ISO_SELECT_MODE`: ISO selection mode (auto/interactive/manual)
- `ISO_PATH`: Path to ISO file (auto-detected or manual)
- `INSTALL_SCRIPT`: Installation script name

**Functions**:
- `get_vm_ip()`: Returns current VM IP address
- `select_iso()`: Interactive ISO selector (displays all available ISOs)

**ISO Selection Modes**:
- `auto` (default): Uses latest ISO from Downloads
- `interactive`: Prompts user to select from available ISOs
- `manual`: Uses user-specified ISO_PATH

### `ArchAuto.sh`

Creates and configures the Parallels VM.

**Actions**:
- Deletes existing VM (if any)
- Creates new Linux VM without HDD
- Configures 16GB RAM, 4 CPUs
- Adds 96GB expandable disk
- Attaches Archboot ISO
- Displays boot and SSH setup instructions

### `cpscript.sh`

Transfers scripts and configures SSH access to the running VM.

**Actions**:
- Gets VM IP automatically
- Copies SSH public key for passwordless login
- Configures Ghostty terminal compatibility
- Transfers installation script to `/tmp/`
- Sets execute permissions
- Displays SSH connection command

**SSH options used**: `StrictHostKeyChecking=no`, `UserKnownHostsFile=/dev/null` (for automation)

### `Omarchy-Arm.sh`

Main installation script that runs inside the Archboot VM.

**Configurable variables** (lines 5-11):
- `HOSTNAME`: System hostname
- `ROOT_PASSWORD`: Root password
- `TIMEZONE`: System timezone
- `LOCALE`: System locale
- `DISK_DEFAULT`: Target disk
- `EFI_SIZE`: EFI partition size
- `BOOT_SIZE`: Boot partition size

**Process**:
1. Checks internet connectivity
2. Configures local package cache (if available)
3. Partitions disk with GPT (ESP + XBOOTLDR + root)
4. Formats partitions (FAT32 for boot, ext4 for root)
5. Installs base system with pacstrap
6. Configures system in chroot environment
7. Sets up GRUB bootloader with custom config
8. Installs Arch ARM keyring
9. Creates persistent bash history
10. Unmounts and reboots

**Key features**:
- Auto-detects disk device (sda/vda/nvme)
- Uses local ISO packages when available
- Manual GRUB configuration with UUID replacement
- Fallback UEFI bootloader setup
- Pacman hook for automatic GRUB updates

### `loginvm.sh`

Simple helper script for logging into the installed system.

**Actions**:
- Sources config for VM name and SSH port
- Configures Ghostty terminal compatibility
- Displays SSH connection command

## Branches

### `main` (default)

Clean installation without proxy configuration. Suitable for environments with direct internet access.

### `squid-cache`

Includes proxy configuration files for environments requiring HTTP proxy:
- `AfterArc.sh`: Post-installation script for certificate and proxy setup
- `bashrc`: Proxy environment variables (10.211.55.2:3128)
- `squid-ca-cert.pem`: Squid CA certificate

To use the proxy branch:

```bash
git checkout squid-cache
./AfterArc.sh  # Run after Arch installation completes
```

## Architecture Details

### Partition Layout

```
/dev/sda1 (P1) - 512MiB FAT32 - ESP       → /efi
/dev/sda2 (P2) - 512MiB FAT32 - XBOOTLDR  → /boot
/dev/sda3 (P3) - ~95GiB ext4  - Root      → /
```

### GRUB Configuration

The installation uses a **manual GRUB configuration** rather than `grub-mkconfig`:

1. Creates `grub.cfg` with UUID placeholders
2. Probes for actual UUIDs and PARTUUIDs inside chroot
3. Uses `sed` to replace placeholders with real values
4. This approach avoids ARM-specific issues with grub-mkconfig

### Network Configuration

- **NetworkManager** is used (not systemd-networkd)
- Parallels "Shared Network" provides DHCP
- SSH configured on port **11838** (not 22)
  - Note: Archboot ISO also uses port 11838 by default
- Root login enabled during installation

### Package Management

- Uses local ISO packages first (if available) for faster installation
- Falls back to online repositories when needed
- Configures Arch Linux ARM keyring for package verification

## Troubleshooting

### VM doesn't get an IP address

```bash
# Inside VM
ip addr                          # Check current IP
systemctl restart NetworkManager # Restart networking
dhclient                         # Request DHCP manually
```

### Can't connect via SSH

```bash
# Check SSH is running in VM
systemctl status sshd

# Verify SSH config allows root login
grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config

# Check firewall - may be blocking SSH
iptables -L INPUT -n -v

# If firewall is blocking, allow SSH ports:
iptables -A INPUT -p tcp --dport 11838 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Save rules persistently
mkdir -p /etc/iptables
iptables-save > /etc/iptables/iptables.rules
systemctl enable iptables.service
```

**Note**: The installation script now automatically configures the firewall, but if you're troubleshooting an existing VM, you may need to add these rules manually.

### ISO packages not found

This is normal if using the "latest" or "base" ISO variants. The script will download packages from online repositories instead.

### GRUB doesn't boot after installation

1. Check that ISO was disconnected before reboot
2. Boot into VM UEFI firmware (press ESC during boot)
3. Verify `/efi/EFI/BOOT/BOOTAA64.EFI` exists (fallback bootloader)
4. Manually select boot device from UEFI menu

### Signature verification fails

```bash
# Manually import GPG key
gpg --keyserver keyserver.ubuntu.com --recv-keys 5B7E3FB71B7F10329A1C03AB771DF6627EDF681F

# Verify signature
cd ~/Downloads
gpg --verify archboot-*.iso.sig archboot-*.iso
```

## VM Management Commands

```bash
# List VMs
prlctl list -a

# Get VM info including IP
prlctl list -i omarchy3

# Start/stop VM
prlctl start omarchy3
prlctl stop omarchy3

# Delete VM
prlctl delete omarchy3

# Take snapshot
prlctl snapshot omarchy3 --name "fresh-install"

# Restore snapshot
prlctl snapshot-list omarchy3
prlctl snapshot-switch omarchy3 --id {snapshot-id}
```

## Contributing

Issues and pull requests are welcome. When contributing, please:

1. Test on Apple Silicon Mac with Parallels Desktop
2. Maintain compatibility with the latest Archboot ARM ISO
3. Update documentation for any configuration changes
4. Follow existing script structure and commenting style

## License

This project is provided as-is for educational and automation purposes.

## Credits

- **Omarchy**: https://omarchy.org/
- **Archboot**: https://gitlab.archlinux.org/tpowa/archboot
- **Omarchy ARM Port**: https://github.com/basecamp/omarchy/pull/1897
- **Arch Linux ARM**: https://archlinuxarm.org
