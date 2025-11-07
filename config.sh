#!/bin/bash
# Centralized configuration for Arch VM automation

# VM Configuration
VM_NAME="omarchy3"
SSH_PORT="11838"

# Function to get VM IP
get_vm_ip() {
    prlctl list -i "$VM_NAME" | grep "IP" | awk '{print $3}' | cut -d',' -f1
}

# Auto-detect latest VERSION from downloaded ISOs
# This will find the most recently modified archboot ISO in Downloads
LATEST_ISO=$(ls -t "$HOME/Downloads"/archboot-*-aarch64-ARCH-*.iso 2>/dev/null | head -n1)

if [ -n "$LATEST_ISO" ]; then
    # Extract VERSION from the ISO filename
    VERSION=$(basename "$LATEST_ISO" | grep -o '[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-[0-9]\{2\}\.[0-9]\{2\}-[0-9.]*-[0-9]*')
    ISO_PATH="$LATEST_ISO"
else
    # Fallback to manual version if no ISO found
    VERSION="2025.11.06-02.28-6.17.7-3"
    ISO_PATH="$HOME/Downloads/archboot-$VERSION-aarch64-ARCH-latest-aarch64.iso"
fi

# Installation Files
INSTALL_SCRIPT="Omarchy-Arm.sh"
