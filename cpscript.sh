#!/bin/bash
# Script to copy installation files to Archboot VM

# Source centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# SSH options for non-interactive use
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "==================================="
echo "Copy Scripts to VM"
echo "==================================="
echo ""

# Get VM IP
IP=$(prlctl list -i $VM_NAME | grep "IP" | awk '{print $3}' | cut -d',' -f1)

if [ -z "$IP" ]; then
    echo "Error: Could not get IP address for VM '$VM_NAME'"
    echo "Make sure the VM is running"
    exit 1
fi

echo "VM: $VM_NAME"
echo "IP: $IP"
echo ""

# Check SSH key authentication
echo "Checking SSH key authentication..."
if ssh -p $SSH_PORT $SSH_OPTS -o BatchMode=yes -o ConnectTimeout=5 root@$IP "echo 'ok'" 2>/dev/null | grep -q "ok"; then
    echo "✓ SSH key already configured"
else
    echo "⚠ SSH key not configured, installing..."
    if ssh-copy-id -p $SSH_PORT $SSH_OPTS root@$IP 2>/dev/null; then
        echo "✓ SSH key installed"
    else
        echo "⚠ Failed to install SSH key (may need password)"
    fi
fi
echo ""

# Check and install Ghostty terminfo
echo "Checking Ghostty terminal compatibility..."
if ssh -p $SSH_PORT $SSH_OPTS root@$IP "infocmp xterm-ghostty >/dev/null 2>&1"; then
    echo "✓ xterm-ghostty terminfo already installed"
else
    if command -v infocmp >/dev/null 2>&1 && infocmp -x xterm-ghostty >/dev/null 2>&1; then
        echo "⚠ xterm-ghostty not found on VM, installing..."
        if infocmp -x xterm-ghostty | ssh -p $SSH_PORT $SSH_OPTS root@$IP -- tic -x - 2>/dev/null; then
            echo "✓ xterm-ghostty terminfo installed"
        else
            echo "⚠ Failed to install terminfo"
        fi
    else
        echo "⚠ xterm-ghostty not available on host (Ghostty not installed)"
    fi
fi
echo ""

# Copy installation script
echo "Copying installation files..."
scp -P $SSH_PORT $SSH_OPTS $INSTALL_SCRIPT root@$IP:/tmp/. 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ Copied $INSTALL_SCRIPT to /tmp/"
else
    echo "✗ Failed to copy $INSTALL_SCRIPT"
fi

# Copy bashrc if it exists (for squid-cache branch)
if [ -f "bashrc" ]; then
    scp -P $SSH_PORT $SSH_OPTS bashrc root@$IP:/tmp/. 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Copied bashrc to /tmp/"
    else
        echo "✗ Failed to copy bashrc"
    fi
fi

# Set executable permission
ssh -p $SSH_PORT $SSH_OPTS root@$IP chmod +x /tmp/$INSTALL_SCRIPT 2>/dev/null
echo "✓ Set executable permission on $INSTALL_SCRIPT"
echo ""

echo "==================================="
echo "Setup Complete"
echo "==================================="
echo ""
echo "Connect to VM and run installation:"
echo "  ssh -p $SSH_PORT $SSH_OPTS root@$IP"
echo "  /tmp/$INSTALL_SCRIPT"
echo ""
echo "After reboot, check VM IP and reconnect"
echo ""
