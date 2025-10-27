#!/bin/bash
# Complete automation script for Parallels

VM_NAME="omarchy2"
INSTALL_SCRIPT="Omarchy-Arm-bare.sh"
SSH_PORT="11838"

IP=$(prlctl list -i $VM_NAME | grep "IP" | awk '{print $3}' | cut -d',' -f1)
ssh-copy-id -p $SSH_PORT root@$IP
scp -P $SSH_PORT $INSTALL_SCRIPT root@$IP:/tmp/.
ssh -p $SSH_PORT root@$IP chmod +x /tmp/$INSTALL_SCRIPT

echo "ssh -p $SSH_PORT root@\$IP" 
