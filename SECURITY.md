# Security Policy

## ⚠️ Important Security Considerations

This repository contains automation scripts for setting up virtual machines. Please read and understand the following security implications before use.

### Default Credentials

**WARNING**: The installation script `Omarchy-Arm.sh` contains a default root password configuration:

```bash
ROOT_PASSWORD="root"  # Line 6 in Omarchy-Arm.sh
```

**This is intentionally set to a simple default value for LOCAL VIRTUAL MACHINE testing purposes.**

#### 🔒 Security Recommendations

1. **CHANGE THE DEFAULT PASSWORD** before using in any environment:
   - Edit `Omarchy-Arm.sh` line 6
   - Set `ROOT_PASSWORD` to a strong password
   - Or configure SSH key-based authentication after installation

2. **This is for LOCAL VMs ONLY**:
   - These scripts are designed for Parallels Desktop VMs on your local Mac
   - VMs use Parallels "Shared Network" which is isolated from external networks
   - **DO NOT** expose these VMs directly to the internet with default credentials

3. **After Installation**:
   ```bash
   # SSH into the installed system
   ssh -p 11838 root@<VM_IP>

   # Change the root password immediately
   passwd

   # Or disable password authentication and use SSH keys only
   sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   systemctl restart sshd
   ```

4. **For Production Use**:
   - Generate strong passwords using a password manager
   - Implement SSH key-based authentication
   - Disable root login over SSH
   - Configure firewall rules
   - Use non-default SSH ports (already configured to 11838)

### Why Default Credentials Exist in This Repository

This is an **automation and educational repository** where:
- The focus is on streamlining VM setup for development/testing
- Users are expected to customize variables before use
- Default values serve as examples and working baselines
- VMs are isolated in local network environments

The `ROOT_PASSWORD` variable is:
- ✅ Clearly marked in documentation as requiring customization
- ✅ Configurable at the top of the script (line 6)
- ✅ Only used in local VM environments
- ✅ Documented with security warnings in README.md

### Reporting Security Issues

If you discover a security vulnerability in these scripts, please:

1. **DO NOT** open a public issue
2. Email the repository maintainer directly
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

## Secure Usage Checklist

Before running these scripts:

- [ ] I have reviewed `Omarchy-Arm.sh` and understand the default credentials
- [ ] I have changed `ROOT_PASSWORD` to a secure value (if needed)
- [ ] I understand these VMs are for local development/testing
- [ ] I will change the root password after installation
- [ ] I will not expose the VM directly to the internet with default credentials

## Security Best Practices

### After VM Installation

1. **Change Root Password**:
   ```bash
   passwd  # Set a strong password
   ```

2. **Create Non-Root User**:
   ```bash
   useradd -m -G wheel -s /bin/bash yourusername
   passwd yourusername
   ```

3. **Configure SSH Keys**:
   ```bash
   # On your host Mac
   ssh-copy-id -p 11838 root@<VM_IP>

   # On VM, disable password auth
   sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   systemctl restart sshd
   ```

4. **Disable Root Login** (after setting up non-root user):
   ```bash
   sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
   systemctl restart sshd
   ```

5. **Enable Firewall** (optional for local VMs):
   ```bash
   pacman -S ufw
   ufw default deny incoming
   ufw default allow outgoing
   ufw allow 11838/tcp  # SSH
   ufw enable
   ```

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| squid-cache | :white_check_mark: |

## License

This project is provided as-is for educational and automation purposes. Users are responsible for securing their own VM installations.
