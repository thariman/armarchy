#!/bin/bash
# SSH Troubleshooting Script for Arch Linux ARM VMs

echo "=== SSH Troubleshooting for Parallels VMs ==="
echo ""

# Get VM name from argument or use default
VM_NAME="${1:-omarchy}"

echo "Checking VM: $VM_NAME"
echo ""

# Check VM status
echo "1. VM Status:"
VM_STATUS=$(prlctl list -i "$VM_NAME" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "   ❌ VM '$VM_NAME' not found!"
    echo ""
    echo "Available VMs:"
    prlctl list -a
    exit 1
fi

STATE=$(echo "$VM_STATUS" | grep "State:" | awk '{print $2}')
IP=$(echo "$VM_STATUS" | grep "IP Addresses:" | cut -d: -f2 | awk '{print $1}' | cut -d',' -f1 | xargs)

echo "   State: $STATE"
echo "   IP: $IP"
echo ""

if [ "$STATE" != "running" ]; then
    echo "   ❌ VM is not running!"
    echo "   Start it with: prlctl start $VM_NAME"
    exit 1
fi

if [ -z "$IP" ]; then
    echo "   ❌ VM has no IP address!"
    echo "   Troubleshooting steps:"
    echo "   1. Check VM network settings in Parallels"
    echo "   2. Access VM console and run: ip addr"
    echo "   3. Restart NetworkManager: systemctl restart NetworkManager"
    exit 1
fi

echo "   ✓ VM is running with IP: $IP"
echo ""

# Check network connectivity
echo "2. Network Connectivity:"
if ping -c 2 -W 2 "$IP" >/dev/null 2>&1; then
    echo "   ✓ VM is reachable (ping successful)"
else
    echo "   ❌ Cannot ping VM!"
    echo "   Check Parallels network configuration"
    exit 1
fi
echo ""

# Check SSH ports
echo "3. SSH Port Status:"
echo "   Checking port 11838..."
if timeout 2 bash -c "echo > /dev/tcp/$IP/11838" 2>/dev/null; then
    echo "   ✓ Port 11838 is OPEN"
    PORT_11838="open"
else
    echo "   ❌ Port 11838 is CLOSED/FILTERED"
    PORT_11838="closed"
fi

echo "   Checking port 22..."
if timeout 2 bash -c "echo > /dev/tcp/$IP/22" 2>/dev/null; then
    echo "   ✓ Port 22 is OPEN"
    PORT_22="open"
else
    echo "   ❌ Port 22 is CLOSED/FILTERED"
    PORT_22="closed"
fi
echo ""

# Provide recommendations
echo "4. Troubleshooting Recommendations:"
echo ""

if [ "$PORT_11838" = "closed" ] && [ "$PORT_22" = "closed" ]; then
    echo "   ❌ Both SSH ports are closed!"
    echo ""
    echo "   This usually means SSH is not running. Access VM console and:"
    echo ""
    echo "   # Check if SSH is installed"
    echo "   which sshd"
    echo ""
    echo "   # Check if SSH service is running"
    echo "   systemctl status sshd"
    echo ""
    echo "   # If not running, start it:"
    echo "   systemctl start sshd"
    echo "   systemctl enable sshd"
    echo ""
    echo "   # Check which port SSH is listening on:"
    echo "   ss -tlnp | grep sshd"
    echo "   # or"
    echo "   netstat -tlnp | grep sshd"
    echo ""

elif [ "$PORT_11838" = "closed" ] && [ "$PORT_22" = "open" ]; then
    echo "   ⚠️  SSH is running on port 22 (not 11838)"
    echo ""
    echo "   Try connecting to port 22:"
    echo "   ssh root@$IP"
    echo ""
    echo "   Or update SSH config to use port 11838:"
    echo "   1. Edit /etc/ssh/sshd_config on the VM"
    echo "   2. Set: Port 11838"
    echo "   3. Restart: systemctl restart sshd"
    echo ""

elif [ "$PORT_11838" = "open" ]; then
    echo "   ✓ SSH port 11838 is open!"
    echo ""
    echo "   Try connecting with different users:"
    echo ""
    echo "   # Try root user:"
    echo "   ssh -p 11838 root@$IP"
    echo ""
    echo "   # Try specific user:"
    echo "   ssh -p 11838 thariman@$IP"
    echo ""
    echo "   # Try with verbose output to see authentication details:"
    echo "   ssh -p 11838 -v root@$IP"
    echo ""
    echo "   Common issues:"
    echo "   - Wrong username (VM might only have 'root' user)"
    echo "   - Password authentication disabled"
    echo "   - SSH keys not set up properly"
    echo ""
    echo "   To check users on the VM (from console):"
    echo "   cat /etc/passwd | grep -E 'root|thariman'"
    echo ""
fi

echo "5. Quick Test Commands:"
echo ""
echo "   # Test with root user:"
echo "   ssh -p 11838 root@$IP"
echo ""
echo "   # Test with password authentication explicitly enabled:"
echo "   ssh -p 11838 -o PreferredAuthentications=password root@$IP"
echo ""
echo "   # Check SSH configuration on VM (from console):"
echo "   grep -E '^Port|^PermitRootLogin|^PasswordAuthentication' /etc/ssh/sshd_config"
echo ""

echo "=== End of Troubleshooting ==="
