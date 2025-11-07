#!/bin/bash
# Centralized configuration for Arch VM automation

# VM Configuration
VM_NAME="omarchy3"
SSH_PORT="11838"
ISO_SELECT_MODE="manual"
ISO_PATH="/Users/thariman/Downloads/archboot-2025.10.31-02.26-6.17.6-1-aarch64-ARCH-local-aarch64.iso"

# Function to get VM IP
get_vm_ip() {
    prlctl list -i "$VM_NAME" | grep "IP" | awk '{print $3}' | cut -d',' -f1
}

# Function to select ISO interactively
select_iso() {
    # Find all available ISOs
    mapfile -t AVAILABLE_ISOS < <(ls -t "$HOME/Downloads"/archboot-*-aarch64-ARCH-*.iso 2>/dev/null)

    if [ ${#AVAILABLE_ISOS[@]} -eq 0 ]; then
        echo "Error: No Archboot ISOs found in $HOME/Downloads/"
        echo "Run ./get_latest_version.sh to download an ISO first"
        return 1
    fi

    echo ""
    echo "=== Available Archboot ISOs ==="
    echo ""

    local idx=1
    for iso in "${AVAILABLE_ISOS[@]}"; do
        local filename=$(basename "$iso")
        local size=$(ls -lh "$iso" | awk '{print $5}')
        local date=$(ls -l "$iso" | awk '{print $6, $7, $8}')

        # Extract version from filename
        local version=$(echo "$filename" | grep -o '[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-[0-9]\{2\}\.[0-9]\{2\}-[0-9.]*-[0-9]*')

        # Determine variant
        local variant="base"
        if [[ "$filename" == *"local"* ]]; then
            variant="local (full packages)"
        elif [[ "$filename" == *"latest"* ]]; then
            variant="latest"
        fi

        echo "$idx) $filename"
        echo "   Version: $version | Variant: $variant | Size: $size | Date: $date"
        echo ""
        ((idx++))
    done

    echo "0) Enter custom ISO path"
    echo ""

    # Prompt for selection
    read -p "Select ISO to use [1-${#AVAILABLE_ISOS[@]}] (default: 1): " choice

    # Default to 1 if empty
    choice=${choice:-1}

    if [ "$choice" == "0" ]; then
        read -p "Enter full path to ISO file: " custom_iso
        if [ -f "$custom_iso" ]; then
            echo "$custom_iso"
            return 0
        else
            echo "Error: ISO file not found: $custom_iso"
            return 1
        fi
    elif [ "$choice" -ge 1 ] && [ "$choice" -le ${#AVAILABLE_ISOS[@]} ] 2>/dev/null; then
        local selected_iso="${AVAILABLE_ISOS[$((choice-1))]}"
        echo "$selected_iso"
        return 0
    else
        echo "Error: Invalid selection"
        return 1
    fi
}

# ISO Selection Mode
# Set ISO_SELECT_MODE to one of:
#   "auto"        - Use latest ISO (default)
#   "interactive" - Prompt user to select from available ISOs
#   "manual"      - Use ISO_PATH variable defined below
ISO_SELECT_MODE="${ISO_SELECT_MODE:-auto}"

case "$ISO_SELECT_MODE" in
    interactive)
        # Interactive selection
        SELECTED_ISO=$(select_iso)
        if [ $? -eq 0 ] && [ -n "$SELECTED_ISO" ]; then
            ISO_PATH="$SELECTED_ISO"
            VERSION=$(basename "$ISO_PATH" | grep -o '[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-[0-9]\{2\}\.[0-9]\{2\}-[0-9.]*-[0-9]*')
            echo "Selected ISO: $(basename "$ISO_PATH")"
        else
            echo "Error: No ISO selected, aborting"
            exit 1
        fi
        ;;

    manual)
        # Manual path - user defines ISO_PATH below
        # Uncomment and set your preferred ISO:
        # ISO_PATH="$HOME/Downloads/archboot-2025.11.03-02.26-6.17.7-1-aarch64-ARCH-local-aarch64.iso"

        if [ -z "$ISO_PATH" ]; then
            echo "Error: ISO_SELECT_MODE is 'manual' but ISO_PATH is not set"
            echo "Edit config.sh and set ISO_PATH to your desired ISO file"
            exit 1
        fi

        if [ ! -f "$ISO_PATH" ]; then
            echo "Error: ISO file not found: $ISO_PATH"
            exit 1
        fi

        VERSION=$(basename "$ISO_PATH" | grep -o '[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-[0-9]\{2\}\.[0-9]\{2\}-[0-9.]*-[0-9]*')
        ;;

    auto|*)
        # Auto-detect latest ISO (default behavior)
        LATEST_ISO=$(ls -t "$HOME/Downloads"/archboot-*-aarch64-ARCH-*.iso 2>/dev/null | head -n1)

        if [ -n "$LATEST_ISO" ]; then
            # Extract VERSION from the ISO filename
            VERSION=$(basename "$LATEST_ISO" | grep -o '[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-[0-9]\{2\}\.[0-9]\{2\}-[0-9.]*-[0-9]*')
            ISO_PATH="$LATEST_ISO"
        else
            # Fallback to manual version if no ISO found
            VERSION="2025.11.06-02.28-6.17.7-3"
            ISO_PATH="$HOME/Downloads/archboot-$VERSION-aarch64-ARCH-latest-aarch64.iso"
            echo "Warning: No ISO found in Downloads, using fallback path"
        fi
        ;;
esac

# Installation Files
INSTALL_SCRIPT="Omarchy-Arm.sh"
