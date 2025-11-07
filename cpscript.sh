#!/bin/bash
# Complete automation script for Parallels

# Source centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# SSH options for non-interactive use
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

IP=$(prlctl list -i $VM_NAME | grep "IP" | awk '{print $3}' | cut -d',' -f1)
ssh-copy-id -p $SSH_PORT $SSH_OPTS root@$IP
infocmp -x xterm-ghostty | ssh -p $SSH_PORT $SSH_OPTS root@$IP -- tic -x -
scp -P $SSH_PORT $SSH_OPTS $INSTALL_SCRIPT root@$IP:/tmp/.
scp -P $SSH_PORT $SSH_OPTS bashrc root@$IP:/tmp/.
ssh -p $SSH_PORT $SSH_OPTS root@$IP chmod +x /tmp/$INSTALL_SCRIPT

echo "ssh -p $SSH_PORT $SSH_OPTS root@$IP" 
echo "run /tmp/$INSTALL_SCRIPT"
echo "after reboot check the vm IP and ssh"
