#!/bin/bash
# Fix SSH firewall blocking issue on Arch Linux VM
# Run this script INSIDE the Arch Linux VM to permanently allow SSH

echo "==================================="
echo "SSH Firewall Fix Script"
echo "==================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Add iptables rules for SSH
echo "1. Checking and adding iptables rules to allow SSH..."

# Check and add rule for port 11838
if iptables -C INPUT -p tcp --dport 11838 -j ACCEPT 2>/dev/null; then
    echo "   ✓ Port 11838 already allowed"
else
    iptables -A INPUT -p tcp --dport 11838 -j ACCEPT
    echo "   ✓ Port 11838 rule added"
fi

# Check and add rule for port 22
if iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null; then
    echo "   ✓ Port 22 already allowed"
else
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    echo "   ✓ Port 22 rule added"
fi
echo ""

# Save iptables rules
echo "2. Making iptables rules persistent..."

# Check if iptables-persistent is available (Debian/Ubuntu style)
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save
    echo "   ✓ Rules saved with netfilter-persistent"
elif command -v iptables-save >/dev/null 2>&1; then
    # Arch Linux method - save to /etc/iptables/iptables.rules
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/iptables.rules
    echo "   ✓ Rules saved to /etc/iptables/iptables.rules"

    # Enable iptables service to load rules on boot
    if systemctl list-unit-files | grep -q "iptables.service"; then
        systemctl enable iptables.service
        echo "   ✓ iptables service enabled"
    else
        echo "   ⚠ Warning: iptables service not found"
        echo "   Rules saved but may not persist after reboot"
        echo "   Install iptables package: pacman -S iptables"
    fi
else
    echo "   ⚠ Warning: Could not save iptables rules automatically"
    echo "   Rules are active but may not persist after reboot"
fi
echo ""

# Verify rules are active
echo "3. Verifying current rules..."
if iptables -L INPUT -n | grep -E "dpt:11838|dpt:22" >/dev/null; then
    echo "   ✓ SSH firewall rules are active:"
    iptables -L INPUT -n -v | grep -E "dpt:11838|dpt:22"
else
    echo "   ✗ No SSH rules found in iptables!"
fi
echo ""

echo "==================================="
echo "Summary"
echo "==================================="
echo ""
echo "✓ SSH ports 11838 and 22 are now allowed through the firewall"
echo "✓ You should be able to SSH into this VM now"
echo ""
echo "To verify from your host machine, run:"
echo "  ssh -p 11838 root@$(ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)"
echo ""
echo "==================================="
