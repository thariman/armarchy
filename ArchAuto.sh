#!/bin/bash
# Complete automation script for Parallels

VM_NAME="omarchy"
ISO_PATH="$HOME/Downloads/archboot-2025.10.05-02.24-6.16.7-1-aarch64-ARCH-local-aarch64.iso"
CONFIG_PATH="$HOME/ArchbootAuto/arch-config"
#SCRIPT_URL="https://raw.githubusercontent.com/picodotdev/alis/master/download.sh"

# Create VM
prlctl create "$VM_NAME" --distribution linux --ostype linux --no-hdd
prlctl set "$VM_NAME" --memsize 16384 --cpus 4
prlctl set "$VM_NAME" --device-add hdd --type expand --size 98304
prlctl set "$VM_NAME" --device-set cdrom0 --image "$ISO_PATH" --connect
echo "start vm"
echo "curl https://raw.githubusercontent.com/thariman/armarchy/refs/heads/main/archboot-autorun.template"
echo "before reboot don't forget to detach cdrom"
