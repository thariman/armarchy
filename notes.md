

https://release.archboot.com/aarch64/latest/iso/archboot-2025.10.05-02.24-6.16.7-1-aarch64-ARCH-local-aarch64.iso

https://release.archboot.com/aarch64/latest/iso/

prlctl set omarchy --cpus 4 --memsize 16384 --device-set cdrom0 --image ~/Downloads/archboot-2025.10.05-02.24-6.16.7-1-aarch64-ARCH-local-aarch64.iso --connect

docker-compose up -d
ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1

edit /etc/pacman.conf
XferCommand = /usr/bin/curl --proxy http://{{your_mac_ip}}:8080 -L -C - -f -o %o %u

packman -S wget
Enable parallel tools ( Actions Install Parallel Tools )
wget -qO- https://raw.githubusercontent.com/jondkinney/armarchy/amarchy-3-x/boot.sh | OMARCHY_REPO=jondkinney/armarchy OMARCHY_REF=amarchy-3-x bash

