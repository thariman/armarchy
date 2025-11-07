#!/bin/bash
# Complete automation script for Parallels

# Source centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

IP=$(prlctl list -i $VM_NAME | grep "IP" | awk '{print $3}' | cut -d',' -f1)
ssh-copy-id -p $SSH_PORT root@$IP
infocmp -x xterm-ghostty | ssh -p $SSH_PORT root@$IP -- tic -x -
scp -P $SSH_PORT ~/nginx-proxy/ssl-ca/ca-cert.pem root@$IP:/tmp/.
scp -P $SSH_PORT bashrc root@$IP:/tmp/.
ssh -p $SSH_PORT root@$IP "cp /tmp/ca-cert.pem /etc/ca-certificates/trust-source/anchors/"
ssh -p $SSH_PORT root@$IP "sudo trust extract-compat"
ssh -p $SSH_PORT root@$IP "cp /tmp/bashrc /root/.bashrc"
echo "ssh -p $SSH_PORT root@$IP" 
