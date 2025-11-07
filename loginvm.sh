#!/bin/bash
# Login helper script for Parallels VM

# Source centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# SSH options for non-interactive use
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "==================================="
echo "VM Login Helper"
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
echo "Port: $SSH_PORT"
echo ""

# Check if we can connect with SSH key
echo "Checking SSH key authentication..."
if ssh -p $SSH_PORT $SSH_OPTS -o BatchMode=yes -o ConnectTimeout=5 root@$IP "echo 'Key auth works'" 2>/dev/null | grep -q "Key auth works"; then
    echo "✓ SSH key authentication already configured"
else
    echo "⚠ SSH key authentication not configured"
    echo "Setting up SSH key..."

    # Copy SSH key to VM
    if ssh-copy-id -p $SSH_PORT $SSH_OPTS root@$IP 2>/dev/null; then
        echo "✓ SSH key installed successfully"
    else
        echo "⚠ Failed to install SSH key (you may need to enter password manually)"
    fi
fi
echo ""

# Check if xterm-ghostty terminfo is installed on VM
echo "Checking Ghostty terminal compatibility..."
if ssh -p $SSH_PORT $SSH_OPTS root@$IP "infocmp xterm-ghostty >/dev/null 2>&1"; then
    echo "✓ xterm-ghostty terminfo already installed"
else
    echo "⚠ xterm-ghostty terminfo not found, installing..."

    # Check if ghostty is available on host
    if command -v infocmp >/dev/null 2>&1; then
        if infocmp -x xterm-ghostty >/dev/null 2>&1; then
            echo "Installing xterm-ghostty terminfo to VM..."
            if infocmp -x xterm-ghostty | ssh -p $SSH_PORT $SSH_OPTS root@$IP -- tic -x - 2>/dev/null; then
                echo "✓ xterm-ghostty terminfo installed successfully"
            else
                echo "⚠ Failed to install xterm-ghostty terminfo"
            fi
        else
            echo "⚠ xterm-ghostty not available on host (Ghostty may not be installed)"
        fi
    else
        echo "⚠ infocmp command not found on host"
    fi
fi
echo ""

echo "==================================="
echo "Setup Complete"
echo "==================================="
echo ""
echo "Connect to VM with:"
echo "  ssh -p $SSH_PORT $SSH_OPTS root@$IP"
echo ""
