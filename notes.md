
Github pull request for Arm version
https://github.com/basecamp/omarchy/pull/1897


https://release.archboot.com/aarch64/latest/iso/archboot-2025.10.05-02.24-6.16.7-1-aarch64-ARCH-local-aarch64.iso

https://release.archboot.com/aarch64/latest/iso/

prlctl create omarchy -d linux
prlctl set omarchy --cpus 4 --memsize 16384 --device-set cdrom0 --image ~/Downloads/archboot-2025.10.05-02.24-6.16.7-1-aarch64-ARCH-local-aarch64.iso --connect

docker-compose up -d
ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1

#Check if my docker proxy is up
curl -sS -I -x http://10.211.55.2:8080 http://archlinux.org | sed -n '1,5p'

start vm
go online
set http://10.211.55.2:8080 as proxy
1 Launch Archboot Setup
Setup
1 Prepare Storage Device
1 Quick Setup
/dev/sda 64G
PARTUUID
/efi MULTIBOOT
512 EFI
512 XTENDED
256 SWAP
ext4
Filesystem ued for / and /home? Yes 0

2 Install Packages
3 Configure System  root passwrd, editor, systemd back
4 Install Bootloader  GRUB_UEFI






edit /etc/pacman.conf
XferCommand = /usr/bin/curl --proxy http://10.211.55.2:8080 --proxy-insecure -L -C - -f -o %o %u

packman -S wget
Enable parallel tools ( Actions Install Parallel Tools )
wget -qO- https://raw.githubusercontent.com/jondkinney/armarchy/amarchy-3-x/boot.sh | OMARCHY_REPO=jondkinney/armarchy OMARCHY_REF=amarchy-3-x-dev bash

