#!/bin/bash
# Script to extract the latest VERSION from Archboot release page

# URL to fetch
URL="https://release.archboot.com/aarch64/latest/iso/"

# Fetch the page and extract VERSION from ISO filename
# Pattern: archboot-VERSION-aarch64-ARCH-*.iso
VERSION=$(curl -sL "$URL" | grep -o 'archboot-[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-[0-9]\{2\}\.[0-9]\{2\}-[0-9.]*-[0-9]*-aarch64' | head -n1 | sed 's/archboot-//;s/-aarch64//')

if [ -z "$VERSION" ]; then
    echo "Error: Could not extract VERSION from $URL" >&2
    exit 1
fi

echo "Latest VERSION: $VERSION"
echo ""

# Ask user which ISO to download
echo "Which ISO variant would you like to download?"
echo "1) local  - archboot-$VERSION-aarch64-ARCH-local-aarch64.iso (largest, fastest install, works offline)"
echo "2) latest - archboot-$VERSION-aarch64-ARCH-latest-aarch64.iso (smallest, requires internet)"
echo "3) base   - archboot-$VERSION-aarch64-ARCH-aarch64.iso (medium size, requires internet)"
echo ""
read -p "Enter your choice (1/2/3): " choice

case $choice in
    1|local)
        ISO_TYPE="local"
        ISO_FILE="archboot-$VERSION-aarch64-ARCH-local-aarch64.iso"
        ;;
    2|latest)
        ISO_TYPE="latest"
        ISO_FILE="archboot-$VERSION-aarch64-ARCH-latest-aarch64.iso"
        ;;
    3|base)
        ISO_TYPE="base"
        ISO_FILE="archboot-$VERSION-aarch64-ARCH-aarch64.iso"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Download directory
DOWNLOAD_DIR="$HOME/Downloads"
ISO_URL="${URL}${ISO_FILE}"
SIG_URL="${URL}${ISO_FILE}.sig"
ISO_PATH="$DOWNLOAD_DIR/$ISO_FILE"
SIG_PATH="$DOWNLOAD_DIR/${ISO_FILE}.sig"

# Archboot GPG key ID (from the error message)
ARCHBOOT_KEY_ID="5B7E3FB71B7F10329A1C03AB771DF6627EDF681F"

# Check if ISO already exists
if [ -f "$ISO_PATH" ]; then
    echo "✓ ISO already exists: $ISO_PATH"
    echo "Skipping download, will verify signature..."
    SKIP_DOWNLOAD=true
else
    echo ""
    echo "Downloading $ISO_FILE to $DOWNLOAD_DIR..."
    echo ""
    SKIP_DOWNLOAD=false
fi

# Download ISO if needed
if [ "$SKIP_DOWNLOAD" = false ]; then
    aria2c -x 10 -k 1M -s 10 -d "$DOWNLOAD_DIR" "$ISO_URL"

    if [ $? -ne 0 ]; then
        echo "Download failed!" >&2
        exit 1
    fi
fi

# Download signature file (always download to get latest)
echo ""
echo "Downloading signature file..."
aria2c -d "$DOWNLOAD_DIR" "$SIG_URL"

if [ $? -eq 0 ]; then
    echo ""
    echo "Importing Archboot GPG key..."
    gpg --keyserver keyserver.ubuntu.com --recv-keys "$ARCHBOOT_KEY_ID" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "Note: Could not import key from keyserver, trying alternative..."
        gpg --keyserver keys.openpgp.org --recv-keys "$ARCHBOOT_KEY_ID" 2>/dev/null
    fi

    echo ""
    echo "Verifying ISO signature..."
    cd "$DOWNLOAD_DIR"

    # Verify using gpg
    gpg --verify "${ISO_FILE}.sig" "$ISO_FILE" 2>&1 | tee /tmp/gpg_verify.log

    if grep -q "Good signature" /tmp/gpg_verify.log; then
        echo ""
        echo "✓ Signature verification PASSED"
        echo "ISO: $ISO_PATH"
        echo "Deleting signature file..."
        rm -f "$SIG_PATH"
        echo "✓ Signature file deleted"
    elif grep -q "Can't check signature: No public key" /tmp/gpg_verify.log; then
        echo ""
        echo "⚠ WARNING: GPG public key not available"
        echo "ISO: $ISO_PATH"
        echo "The signature file was downloaded but the public key could not be imported."
        echo "You can manually import it with:"
        echo "  gpg --recv-keys $ARCHBOOT_KEY_ID"
        echo "Keeping signature file for manual verification."
    else
        echo ""
        echo "⚠ WARNING: Signature verification failed!"
        echo "ISO: $ISO_PATH"
        cat /tmp/gpg_verify.log
        echo "Keeping signature file for troubleshooting."
    fi

    rm -f /tmp/gpg_verify.log
else
    echo "Warning: Could not download signature file" >&2
fi

echo ""
echo "Download complete!"
echo "ISO saved to: $ISO_PATH" 
