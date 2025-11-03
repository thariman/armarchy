#!/bin/bash
# Complete automation script for Parallels

# Source centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

IP=$(prlctl list -i $VM_NAME | grep "IP" | awk '{print $3}' | cut -d',' -f1)
ssh-copy-id -p $SSH_PORT root@$IP
scp -P $SSH_PORT $INSTALL_SCRIPT root@$IP:/tmp/. 
ssh -p $SSH_PORT root@$IP chmod +x /tmp/$INSTALL_SCRIPT

echo "ssh -p $SSH_PORT root@$IP" 
echo "run /tmp/$INSTALL_SCRIPT"
echo "after reboot check the vm IP and ssh"
echo "wget -qO- https://raw.githubusercontent.com/jondkinney/armarchy/amarchy-3-x/boot.sh | OMARCHY_REPO=jondkinney/armarchy OMARCHY_REF=amarchy-3-x bash"
