#!/bin/bash
# Complete automation script for Parallels

#https://release.archboot.com/aarch64/latest/iso/

VM_NAME="omarchy2"
ISO_PATH="$HOME/Downloads/archboot-2025.10.23-02.23-6.16.7-1-aarch64-ARCH-latest-aarch64.iso"
INSTALL_SCRIPT="Omarchy-Arm-bare2.sh"
SSH_PORT="11838"

# Create VM
prlctl create "$VM_NAME" --distribution linux --ostype linux --no-hdd
prlctl set "$VM_NAME" --memsize 16384 --cpus 4
prlctl set "$VM_NAME" --device-add hdd --type expand --size 98304
prlctl set "$VM_NAME" --device-set cdrom0 --image "$ISO_PATH" --connect

cat <<EOF

Start VM

#VM shell
edit /etc/ssh/sshd_config
   PermitRootLogin yes
   PasswordAuthentication yes

systemctl restart sshd
passwd #for root

#host shell/terminal
IP=\$(prlctl list -i $VM_NAME | grep "IP" | awk '{print \$3}' | cut -d',' -f1)
scp -P $SSH_PORT $INSTALL_SCRIPT root@\$IP:/tmp/.
ssh -p $SSH_PORT root@\$IP chmod +x /tmp/$INSTALL_SCRIPT

EOF

