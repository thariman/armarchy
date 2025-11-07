#!/bin/bash
# Complete automation script for Parallels

# Source centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# SSH options for non-interactive use
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

IP=$(prlctl list -i $VM_NAME | grep "IP" | awk '{print $3}' | cut -d',' -f1)
infocmp -x xterm-ghostty | ssh -p $SSH_PORT $SSH_OPTS root@$IP -- tic -x -
echo "ssh -p $SSH_PORT $SSH_OPTS root@$IP" 
