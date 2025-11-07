#!/bin/bash
# Script to retrieve Omarchy installation logs from VM

# Source centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# SSH options for non-interactive use
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "==================================="
echo "Omarchy Log Retrieval Script"
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

# Check if we can connect
echo "Testing SSH connection..."
if ! ssh -p $SSH_PORT $SSH_OPTS root@$IP "echo 'Connection successful'" 2>/dev/null; then
    echo "Error: Cannot connect to VM via SSH"
    echo "Check that:"
    echo "  1. VM is running"
    echo "  2. SSH is running on the VM"
    echo "  3. Firewall allows SSH on port $SSH_PORT"
    exit 1
fi
echo "✓ SSH connection successful"
echo ""

# Find Omarchy installation log files
echo "Looking for Omarchy installation logs on VM..."
OMARCHY_LOGS=$(ssh -p $SSH_PORT $SSH_OPTS root@$IP "find /var/log -name 'omarchy-install-*.log' 2>/dev/null" 2>/dev/null)

if [ -z "$OMARCHY_LOGS" ]; then
    echo "No Omarchy installation logs found in /var/log"
    echo ""
    echo "Checking alternative locations..."
    OMARCHY_LOGS=$(ssh -p $SSH_PORT $SSH_OPTS root@$IP "find /home /root -name 'omarchy-install-*.log' 2>/dev/null" 2>/dev/null)

    if [ -z "$OMARCHY_LOGS" ]; then
        echo "No Omarchy installation logs found on VM"
        echo ""
        echo "Logs are typically located at:"
        echo "  /var/log/omarchy-install-YYYY-MM-DD_HH-MM-SS.log"
        echo "  or /home/\$USER/omarchy-install-YYYY-MM-DD_HH-MM-SS.log"
        echo ""
        echo "You can manually check with:"
        echo "  ssh -p $SSH_PORT root@$IP"
        echo "  find /var/log /home /root -name 'omarchy-install-*.log'"
        exit 1
    else
        echo "Found logs in alternative location:"
    fi
fi

echo "Found Omarchy installation logs:"
echo "$OMARCHY_LOGS"
echo ""

# Download each log file
echo "Downloading logs..."
for log_path in $OMARCHY_LOGS; do
    log_file=$(basename "$log_path")

    # Extract timestamp from omarchy-install log filename
    # Format: omarchy-install-2025-11-03_17-07-13.log
    if [[ "$log_file" =~ omarchy-install-([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2})\.log ]]; then
        TIMESTAMP="${BASH_REMATCH[1]}"

        echo "  Downloading $log_file..."
        scp -P $SSH_PORT $SSH_OPTS root@$IP:"$log_path" "$SCRIPT_DIR/$log_file" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo "  ✓ Saved to: $SCRIPT_DIR/$log_file"

            # Now get the pacman.log from VM and rename it with the same timestamp
            echo "  Looking for pacman.log..."
            PACMAN_LOG=$(ssh -p $SSH_PORT $SSH_OPTS root@$IP "ls /var/log/pacman.log 2>/dev/null" 2>/dev/null)

            if [ -n "$PACMAN_LOG" ]; then
                PACMAN_DEST="$SCRIPT_DIR/pacman-$TIMESTAMP.log"
                echo "  Downloading pacman.log..."
                scp -P $SSH_PORT $SSH_OPTS root@$IP:/var/log/pacman.log "$PACMAN_DEST" 2>/dev/null

                if [ $? -eq 0 ]; then
                    echo "  ✓ Saved to: $PACMAN_DEST"
                else
                    echo "  ⚠ Failed to download pacman.log"
                fi
            else
                echo "  ⚠ pacman.log not found on VM"
            fi
        else
            echo "  ✗ Failed to download $log_file"
        fi
    else
        echo "  Downloading $log_file (no timestamp detected)..."
        scp -P $SSH_PORT $SSH_OPTS root@$IP:"$log_path" "$SCRIPT_DIR/$log_file" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo "  ✓ Saved to: $SCRIPT_DIR/$log_file"
        else
            echo "  ✗ Failed to download $log_file"
        fi
    fi

    echo ""
done

echo "==================================="
echo "Log retrieval complete!"
echo "==================================="
echo ""
echo "Downloaded logs are in: $SCRIPT_DIR/"
echo ""

# List downloaded logs
echo "Downloaded files:"
ls -lh "$SCRIPT_DIR"/omarchy-install-*.log "$SCRIPT_DIR"/pacman-*.log 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""
