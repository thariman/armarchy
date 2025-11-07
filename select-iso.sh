#!/bin/bash
# Helper script to interactively select an ISO for VM creation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set interactive mode and source config
export ISO_SELECT_MODE="interactive"
source "$SCRIPT_DIR/config.sh"

# Display selected ISO
echo ""
echo "=================================="
echo "ISO Selection Complete"
echo "=================================="
echo ""
echo "Selected ISO: $(basename "$ISO_PATH")"
echo "Version: $VERSION"
echo "Full path: $ISO_PATH"
echo ""
echo "This ISO will be used for the next VM creation."
echo ""
echo "To create the VM with this ISO, run:"
echo "  ./ArchAuto.sh"
echo ""
