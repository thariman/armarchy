# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains automation scripts for installing Omarchy on Arch Linux ARM using Parallels Desktop on Apple Silicon (tested on MBP M4 Max). The scripts orchestrate the complete workflow from VM creation to Arch Linux installation and Omarchy deployment.

Related resources:
- Archboot ISO source: https://release.archboot.com/aarch64/latest/iso/
- Omarchy ARM PR: https://github.com/basecamp/omarchy/pull/1897

## Architecture

### Core Workflow

The installation follows a multi-stage process:

1. **ISO Download & VM Setup** (`get_latest_version.sh` → `ArchAuto.sh`)
   - Downloads latest Archboot ISO with signature verification
   - Offers three ISO variants (local/latest/base)
   - Creates and configures Parallels VM

2. **Script Transfer** (`cpscript.sh`)
   - Transfers installation scripts to the running Archboot VM
   - Copies necessary configuration files (bashrc, SSL certificates)

3. **Arch Installation** (`Omarchy-Arm.sh`)
   - Automated disk partitioning (GPT: ESP + XBOOTLDR + root)
   - Base Arch ARM installation with pacstrap
   - GRUB bootloader configuration for ARM64 EFI
   - Network and SSH setup with custom port (11838)

4. **Post-Installation** (`AfterArc.sh`)
   - Terminal info setup (for Ghostty terminal)
   - SSL certificate installation and trust configuration
   - Proxy configuration via bashrc

### Key Design Patterns

**Centralized Configuration** (`config.sh`):
- All scripts source this file for VM name, ports, paths
- Auto-detects latest ISO from Downloads directory
- Provides `get_vm_ip()` helper function

**SSH Configuration**:
- Custom port: 11838 (not 22)
  - This matches Archboot ISO's default SSH port
- Root login enabled during setup
- Password authentication used for initial access

**Partition Layout**:
- P1: EFI System Partition (ESP) - 512MiB FAT32 at /efi
- P2: XBOOTLDR partition - 512MiB FAT32 at /boot
- P3: Root partition - remaining space ext4 at /

**GRUB Configuration**:
- Manual grub.cfg with UUID/PARTUUID placeholders replaced during installation
- Fallback bootloader at /efi/EFI/BOOT/BOOTAA64.EFI
- Pacman hook for automatic GRUB updates

**Local Package Caching**:
- Attempts to use ISO-provided packages before downloading
- Reduces installation time and bandwidth usage

## Common Commands

### Complete Installation Workflow

```bash
# 1. Download latest ISO and extract SSH keys
./get_latest_version.sh

# 2. Create and start VM
./ArchAuto.sh
# Follow on-screen prompts to boot VM and configure SSH

# 3. Transfer installation script to VM
./cpscript.sh

# 4. SSH into VM and run installation
ssh -p 11838 root@<VM_IP>
/tmp/Omarchy-Arm.sh

# 5. After reboot, configure proxy and certificates
./AfterArc.sh

# 6. Install Omarchy
ssh -p 11838 root@<VM_IP>
wget -qO- https://raw.githubusercontent.com/jondkinney/armarchy/amarchy-3-x/boot.sh | \
  OMARCHY_REPO=jondkinney/armarchy OMARCHY_REF=amarchy-3-x bash
```

### VM Management

```bash
# Get VM IP address
prlctl list -i omarchy3 | grep "IP" | awk '{print $3}' | cut -d',' -f1

# Start/stop VM
prlctl start omarchy3
prlctl stop omarchy3

# Delete and recreate VM
prlctl delete omarchy3
./ArchAuto.sh
```

### SSH Access

```bash
# Connect with password
ssh -p 11838 root@<VM_IP>

# Connect with Archboot key
ssh -i ~/Downloads/archboot-key -p 11838 root@<VM_IP>

# Copy SSH key for automatic login
ssh-copy-id -p 11838 root@<VM_IP>
```

## Important Configuration Details

### Variable Naming in Scripts

When working with `Omarchy-Arm.sh`, note that variables must be passed to arch-chroot via environment:
- The heredoc at line 119 uses uppercase variables: `HOSTNAME`, `ROOT_PASSWORD`, `TIMEZONE`, `LOCALE`
- These are defined at the top of the script (lines 5-8)

### GRUB Configuration Process

The GRUB setup is non-standard and manual (lines 171-261 in Omarchy-Arm.sh):
1. Creates grub.cfg with placeholders
2. Probes for actual UUIDs and PARTUUIDs inside chroot
3. Uses sed to replace placeholders with real values
4. This avoids issues with grub-mkconfig on ARM

### Disk Device Detection

The script auto-detects disk devices (lines 55-57 in Omarchy-Arm.sh):
- Defaults to /dev/sda (Parallels standard)
- Checks for /dev/vda (virtual disk)
- Checks for /dev/nvme0n1 (NVMe)
- Handles partition naming differences (sda1 vs nvme0n1p1)

### Network Configuration

- NetworkManager is used (not systemd-networkd)
- Parallels "Shared Network" provides DHCP
- Proxy settings in bashrc: 10.211.55.2:3128 (host machine squid proxy)

## Testing

This is primarily an automation script repository. Manual testing involves:

1. Verify ISO download and signature: `./get_latest_version.sh`
2. Test VM creation: `./ArchAuto.sh` (check prlctl output)
3. Test script transfer: `./cpscript.sh` (verify files appear in /tmp on VM)
4. Test installation: Run `Omarchy-Arm.sh` and check for errors during pacstrap, grub-install
5. Test boot: Reboot VM and verify GRUB menu appears and system boots to login

## File Dependencies

When modifying scripts, be aware of these dependencies:

- All scripts depend on `config.sh` for VM_NAME, SSH_PORT, ISO_PATH
- `cpscript.sh` expects `Omarchy-Arm.sh` and `bashrc` to exist
- `AfterArc.sh` expects `~/nginx-proxy/ssl-ca/ca-cert.pem` on host
- `Omarchy-Arm.sh` expects `/tmp/bashrc` to create persistent history
