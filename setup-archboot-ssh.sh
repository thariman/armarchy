#!/bin/bash
# Automate Archboot SSH setup for automatic login
# This script configures the Archboot VM to accept SSH key authentication

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "=== Archboot SSH Automation Setup ==="
echo ""

# Get VM IP
echo "Getting VM IP address..."
VM_IP=$(get_vm_ip)

if [ -z "$VM_IP" ]; then
    echo "Error: Could not get VM IP address"
    echo "Make sure the VM '$VM_NAME' is running"
    exit 1
fi

echo "VM IP: $VM_IP"
echo ""

# Check if archboot key exists
if [ ! -f "$ARCHBOOT_KEY" ]; then
    echo "Error: Archboot key not found at $ARCHBOOT_KEY"
    echo "Run ./get_latest_version.sh first to download and extract the key"
    exit 1
fi

# Generate public key if it doesn't exist
ARCHBOOT_PUB_KEY="${ARCHBOOT_KEY}.pub"
if [ ! -f "$ARCHBOOT_PUB_KEY" ]; then
    echo "Generating public key from private key..."
    ssh-keygen -y -f "$ARCHBOOT_KEY" -P "Archboot" > "$ARCHBOOT_PUB_KEY"
    echo "Public key created: $ARCHBOOT_PUB_KEY"
fi

echo ""
echo "=== Configuring SSH on Archboot VM ==="
echo ""
echo "This will:"
echo "1. Enable password authentication temporarily"
echo "2. Set root password to 'archboot'"
echo "3. Install SSH public key for automatic login"
echo "4. Optionally keep password auth enabled or disable it"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Create a temporary script to run on the VM
TMP_SCRIPT="/tmp/setup-ssh-$$"
cat > "$TMP_SCRIPT" << 'EOFSCRIPT'
#!/bin/bash
# Run on Archboot VM to enable SSH

echo "Configuring SSH..."

# Backup original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Enable password and root login
sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH
systemctl restart sshd

# Set root password
echo "root:archboot" | chpasswd

echo "✓ SSH configured with password authentication"
echo "✓ Root password set to: archboot"
EOFSCRIPT

echo "You need to run the following commands in the VM console:"
echo ""
echo "------- Copy and paste these commands in the VM -------"
cat "$TMP_SCRIPT"
echo "-------------------------------------------------------"
echo ""
echo "Press ENTER after you've run the commands in the VM..."
read

rm -f "$TMP_SCRIPT"

echo ""
echo "Testing SSH connection..."
sleep 2

# Test connection with password
if sshpass -p "archboot" ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$VM_IP" "echo 'Connection successful'" 2>/dev/null; then
    echo "✓ Password authentication working"
else
    echo "⚠ Could not connect with password. Please verify the setup."
    echo "Try manually: ssh -p $SSH_PORT root@$VM_IP"
    exit 1
fi

echo ""
echo "Installing SSH public key for automatic login..."

# Copy SSH key
sshpass -p "archboot" ssh-copy-id -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$ARCHBOOT_PUB_KEY" root@"$VM_IP" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ SSH key installed"
else
    echo "⚠ Failed to install SSH key"
    exit 1
fi

echo ""
echo "Testing key-based authentication..."
if ssh -i "$ARCHBOOT_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$VM_IP" "echo 'Key auth successful'" 2>/dev/null; then
    echo "✓ Key-based authentication working!"
else
    echo "⚠ Key authentication test failed"
    exit 1
fi

echo ""
read -p "Do you want to disable password authentication (key-only)? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Disabling password authentication..."
    ssh -i "$ARCHBOOT_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$VM_IP" \
        "sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl restart sshd"
    echo "✓ Password authentication disabled (key-only access)"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "You can now connect automatically with:"
echo "  ssh -i $ARCHBOOT_KEY -p $SSH_PORT root@$VM_IP"
echo ""
echo "Or use the helper alias:"
echo "  alias archboot-ssh='ssh -i $ARCHBOOT_KEY -p $SSH_PORT root@$VM_IP'"
