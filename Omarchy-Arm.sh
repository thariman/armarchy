#!/usr/bin/env bash
set -euo pipefail

### ====== USER VARIABLES (edit if you like) ======
HOSTNAME="ArchLinux"
ROOT_PASSWORD="root"
TIMEZONE="Asia/Jakarta"
LOCALE="en_US.UTF-8"
DISK_DEFAULT="/dev/sda"     # Parallels usually exposes the disk as /dev/sda
EFI_SIZE="512MiB"
BOOT_SIZE="512MiB"
### ==============================================

echo "[*] Arch ARM + Omarchy automated install for Parallels (Apple Silicon)"
echo "[*] This will WIPE the target disk and install Arch ARM + Omarchy."
sleep 2

# ----- Sanity checks -----
if ! ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
  echo "[!] No internet? Make sure DHCP is up (Parallels 'Shared Network')."
  echo "    Try: 'ip addr', 'systemctl restart systemd-networkd' (if needed), or ensure the NIC is up."
  sleep 2
fi

# ----- Configure local ISO repository (if available) -----
echo "[*] Checking for local ISO repository..."

# Try to find the ISO repository location
ISO_REPO=""
for path in "/run/archiso/bootmnt" "/run/archiso/sfs/airootfs" "/var/archboot" "/"; do
  if [ -d "${path}/var/cache/pacman/pkg" ] && [ "$(ls -A ${path}/var/cache/pacman/pkg 2>/dev/null)" ]; then
    ISO_REPO="${path}"
    echo "[*] Found local packages at: ${ISO_REPO}/var/cache/pacman/pkg"
    break
  fi
done

if [ -n "${ISO_REPO}" ]; then
  # Use local package cache
  mkdir -p /var/cache/pacman/pkg
  echo "[*] Copying packages from ISO to local cache..."
  cp -n ${ISO_REPO}/var/cache/pacman/pkg/*.pkg.tar.* /var/cache/pacman/pkg/ 2>/dev/null || true
  
  # Set CacheDir to use local packages first
  sed -i '/^#CacheDir/a CacheDir = /var/cache/pacman/pkg' /etc/pacman.conf 2>/dev/null || true
  
  echo "[*] Local ISO packages configured - pacman will use local cache first"
else
  echo "[*] No local ISO packages found, using online repositories only"
fi

pacman -Sy --noconfirm gdisk parted nvim sudo wget

# Detect candidate disk if present; fall back to /dev/sda
DISK="${DISK_DEFAULT}"
if lsblk -dno NAME,TYPE | grep -q "^vda disk"; then DISK="/dev/vda"; fi
if lsblk -dno NAME,TYPE | grep -q "^nvme0n1 disk"; then DISK="/dev/nvme0n1"; fi

echo "[*] Using disk: ${DISK}"
lsblk -dpno NAME,SIZE,TYPE | grep -E "${DISK}"

read -r -p ">>> FINAL WARNING: This will ERASE ${DISK}. Type 'YES' to continue: " CONFIRM
if [[ "${CONFIRM}" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi

# ----- Partition disk (GPT: EFI + XBOOTLDR + root) -----
echo "[*] Partitioning ${DISK}..."
wipefs -af "${DISK}" || true
sgdisk --zap-all "${DISK}"
partprobe "${DISK}"

# Create partitions: 1 = EFI (ESP), 2 = XBOOTLDR (/boot), 3 = root
sgdisk -n 1:0:+${EFI_SIZE} -t 1:EF00 -c 1:"ESP" "${DISK}"
sgdisk -n 2:0:+${BOOT_SIZE} -t 2:EA00 -c 2:"XBOOTLDR" "${DISK}"
sgdisk -n 3:0:0           -t 3:8300 -c 3:"Linux Root" "${DISK}"
partprobe "${DISK}"

# Figure out partition names (nvme needs 'p' before number)
if [[ "${DISK}" == *"nvme"* ]]; then
  P1="${DISK}p1"
  P2="${DISK}p2"
  P3="${DISK}p3"
else
  P1="${DISK}1"
  P2="${DISK}2"
  P3="${DISK}3"
fi

echo "[*] Formatting..."
mkfs.fat -F32 -n ESP "${P1}"
mkfs.fat -F32 -n XBOOTLDR "${P2}"
mkfs.ext4 -F -L ARCH_ROOT "${P3}"

echo "[*] Mounting..."
mount "${P3}" /mnt
mkdir -p /mnt/efi
mkdir -p /mnt/boot
mount "${P1}" /mnt/efi
mount "${P2}" /mnt/boot

# ----- Bootstrap Arch ARM base -----
# Archboot environment provides pacstrap/arch-chroot.
# Packages: base OS + firmware + bootloader + networking + essentials
echo "[*] Installing base system (this can take a while)..."
pacstrap -K /mnt \
  base linux linux-firmware \
  grub efibootmgr \
  networkmanager openssh \
  sudo git curl vim nano base-devel wget \

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo "Before arch-chroot"

# ----- Configure system inside chroot -----
arch-chroot /mnt /bin/bash <<CHROOT_EOF
set -euo pipefail

# Variables must be passed via environment; we embed them below at the end of heredoc
: "${HOSTNAME:?}"; : "${ROOT_PASSWORD:?}"
: "${TIMEZONE:?}"; : "${LOCALE:?}"

echo "[*] Setting timezone and clock..."
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

echo "[*] Locale..."
if ! grep -q "^${LOCALE} " /etc/locale.gen; then
  echo "${LOCALE} UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

echo "[*] Hostname & hosts..."
echo "${HOSTNAME}" > /etc/hostname
cat >/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

echo "[*] Root password..."
echo "root:${ROOT_PASSWORD}" | chpasswd

echo "[*] Ensure pacman keys for Arch Linux ARM..."
pacman-key --init
pacman-key --populate archlinuxarm || true  # sometimes optional in fresh images

echo "[*] Configure SSH for root access..."
sed -i 's/^#\?Port.*/Port 11838/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

echo "[*] Enable essential services..."
systemctl enable NetworkManager
systemctl enable sshd

echo "[*] Install GRUB (ARM64 EFI)..."
grub-install --directory="/usr/lib/grub/arm64-efi" --target="arm64-efi" --efi-directory="/efi" --bootloader-id="GRUB" --recheck

# Copy font for GRUB (try ter-u16n first, fallback to unicode)
if [ -f /usr/share/grub/ter-u16n.pf2 ]; then
    cp -f /usr/share/grub/ter-u16n.pf2 /boot/grub/fonts/ter-u16n.pf2
else
    cp -f /usr/share/grub/unicode.pf2 /boot/grub/fonts/ter-u16n.pf2 2>/dev/null || true
fi

# Create grub.cfg with placeholder UUIDs (will be replaced later)
cat > /boot/grub/grub.cfg <<'GRUBCFG'
# Include modules - required for boot
insmod part_gpt
insmod part_msdos
insmod fat
insmod fat
insmod ext2
insmod ext2
insmod search_fs_file
insmod search_fs_uuid
insmod search_label
insmod linux
insmod chain
set pager=1
# set debug="all"
set locale_dir="\${prefix}/locale"
if [ "\${grub_platform}" == "efi" ]; then
    insmod all_video
    insmod efi_gop
    if [ "\${grub_cpu}" == "x86_64" ]; then
        insmod bli
        insmod efi_uga
    elif [ "\${grub_cpu}" == "i386" ]; then
        insmod bli
        insmod efi_uga
    fi
elif [ "\${grub_platform}" == "pc" ]; then
    insmod vbe
    insmod vga
    insmod png
fi
insmod video_bochs
insmod video_cirrus
insmod font
search --fs-uuid --no-floppy --set=usr_part --hint-bios=hd0,gpt3 --hint-efi=hd0,gpt3 --hint-baremetal=ahci0,gpt3  ROOTDEV_FS_UUID_PLACEHOLDER
search --fs-uuid --no-floppy --set=root_part --hint-bios=hd0,gpt3 --hint-efi=hd0,gpt3 --hint-baremetal=ahci0,gpt3  ROOTDEV_FS_UUID_PLACEHOLDER
if [ -e "\${prefix}/fonts/ter-u16n.pf2" ]; then
    set _fontfile="\${prefix}/fonts/ter-u16n.pf2"
else
    if [ -e "(\${root_part})/usr/share/grub/ter-u16n.pf2" ]; then
        set _fontfile="(\${root_part})/usr/share/grub/ter-u16n.pf2"
    else
        if [ -e "(\${usr_part})/share/grub/ter-u16n.pf2" ]; then
            set _fontfile="(\${usr_part})/share/grub/ter-u16n.pf2"
        fi
    fi
fi
if loadfont "\${_fontfile}" ; then
    insmod gfxterm
    set gfxmode="auto"

    terminal_input console
    terminal_output gfxterm
fi
# (0) Arch Linux
menuentry "Arch Linux" {
    set gfxpayload="keep"
    search --fs-uuid --no-floppy --set=root --hint-bios=hd0,gpt2 --hint-efi=hd0,gpt2 --hint-baremetal=ahci0,gpt2  BOOTDEV_FS_UUID_PLACEHOLDER
    linux /Image.gz root=PARTUUID=ROOT_PARTUUID_PLACEHOLDER rootfstype=ext4 rw rootflags=rw,noatime 
    initrd /initramfs-linux.img

}
if [ "\${grub_platform}" == "efi" ]; then
    menuentry "UEFI Firmware Setup" {
        fwsetup
        }
fi
menuentry "Reboot System" {
    reboot
}
menuentry "Poweroff System" {
    halt
}

GRUBCFG

# Get actual UUIDs and update grub.cfg
BOOTDEV_FS_UUID="\$(grub-probe --target=fs_uuid /boot)"
ROOTDEV_FS_UUID="\$(grub-probe --target=fs_uuid /)"
USRDEV_FS_UUID="\$(grub-probe --target=fs_uuid /usr)"
ESP_DEV_FS_UUID="\$(grub-probe --target=fs_uuid /efi)"

# Get root PARTUUID
ROOT_DEV="\$(findmnt -no SOURCE /)"
ROOT_PARTUUID="\$(lsblk -rno PARTUUID \${ROOT_DEV} 2>/dev/null || blkid -s PARTUUID -o value \${ROOT_DEV})"

# Replace placeholders in grub.cfg
sed -i "s/BOOTDEV_FS_UUID_PLACEHOLDER/\${BOOTDEV_FS_UUID}/g" /boot/grub/grub.cfg
sed -i "s/ROOTDEV_FS_UUID_PLACEHOLDER/\${ROOTDEV_FS_UUID}/g" /boot/grub/grub.cfg
sed -i "s/USRDEV_FS_UUID_PLACEHOLDER/\${USRDEV_FS_UUID}/g" /boot/grub/grub.cfg
sed -i "s/ROOT_PARTUUID_PLACEHOLDER/\${ROOT_PARTUUID}/g" /boot/grub/grub.cfg

# Create fallback UEFI bootloader
mkdir -p /efi/EFI/BOOT
rm -f /efi/EFI/BOOT/BOOTAA64.EFI
cp -f /efi/EFI/GRUB/grubaa64.efi /efi/EFI/BOOT/BOOTAA64.EFI

# Create pacman hook to update GRUB on upgrades
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/999-grub-uefi.hook <<'HOOK'
[Trigger]
Type = Package
Operation = Upgrade
Target = grub

[Action]
Description = Update GRUB after upgrade...
When = PostTransaction
Exec = /usr/bin/sh -c "grub-install --directory='/usr/lib/grub/arm64-efi' --target='arm64-efi' --efi-directory='/efi' --bootloader-id='GRUB' --recheck"
HOOK

echo "[*] Installing Arch Linux ARM keyring..."
# Try to install the keyring package
if ! pacman -S --noconfirm archlinuxarm-keyring 2>/dev/null; then
  echo "[*] Manually importing Arch Linux ARM keys..."
  pacman-key --recv-keys 77193F152BDBE6A6
  pacman-key --lsign-key 77193F152BDBE6A6
fi
# Refresh package database
pacman -Syu

echo "[*] Setting up persistent command history..."
# Create bash history from history.lst
cat > /root/.bash_history <<'HISTORY'
ip addr
wget -qO- https://raw.githubusercontent.com/jondkinney/armarchy/amarchy-3-x/boot.sh | OMARCHY_REPO=jondkinney/armarchy OMARCHY_REF=amarchy-3-x bash
wget -qO- https://raw.githubusercontent.com/jondkinney/armarchy/amarchy-3-x/boot.sh | OMARCHY_REPO=jondkinney/armarchy OMARCHY_REF=amarchy-3-x-beta bash
HISTORY

# Set proper permissions
chown root:root /root/.bash_history
chmod 600 /root/.bash_history

CHROOT_EOF
# ----- end of chroot config -----

# Unmount & reboot
echo "[*] Installation complete. Unmounting and rebooting..."
umount -R /mnt || true
sync

read -r -p ">>> Going to reboot please disconnect iso Type 'YES' to continue: " CONFIRM
if [[ "${CONFIRM}" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi

reboot
