#!/bin/bash
# Complete automation script for Parallels

#https://release.archboot.com/aarch64/latest/iso/

# Source centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

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
run ./cpscript.sh
EOF

