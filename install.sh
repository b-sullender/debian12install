#!/bin/bash

# Check if device, password and hostname were provided as arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 <device> <password> <hostname>"
    exit 1
fi

# Get target device and password
device="$1"
password="$2"
hostname="$3"

# Safety prompt
read -p "WARNING: This script will erase all data on $device. Continue? [y/N] " confirm
if [ "$confirm" != "y" ]; then
    echo "Aborted."
    exit 1
fi

# Create the directories to mount the new system
sudo mkdir -p /mnt/rootfs/

# Format drive
echo "Creating partitions on $device..."

# Use fdisk to create partitions
cat <<EOF | sudo sfdisk "$device"
label: gpt
device: ${device}
unit: sectors

${device}1 : start=        2048, size=     409600, type=4
${device}2 : start=     411648, size=         0, type=83
EOF

# Format the second partition as ext4 filesystem
sudo mkfs.ext4 -L rootfs "${device}2"

# Mount the second partition
sudo mount "${device}2" /mnt/rootfs/

# Bootstrap the Debian system into the mounted filesystem
sudo debootstrap --include=linux-image-amd64 bookworm /mnt/rootfs/ http://deb.debian.org/debian/

# Install GRUB bootloader
sudo grub-install --root-directory=/mnt/rootfs/ "$device"

# Configure GRUB bootloader
sudo bash -c 'cat > /mnt/rootfs/boot/grub/grub.cfg << "EOF"
set default=0
set timeout=4

menuentry "Debian GNU/Linux" {
    set root=(hd0,gpt2)
    linux /vmlinuz root=/dev/sda2
    initrd /initrd.img
}
EOF'

# Get the UUID of the rootfs partition
UUID=$(sudo blkid -s UUID -o value "${device}2")

# Configure fstab (file system will be read-only without it)
sudo bash -c "cat > /mnt/rootfs/etc/fstab << EOF
# /etc/fstab: static file system information.
#
# <file system> <mount point> <type> <options> <dump> <pass>
# / was on ${device}2 during installation
UUID=$UUID / ext4 errors=remount-ro 0 1
EOF"

# Create a new hostname file
sudo bash -c "cat > /mnt/rootfs/etc/hostname << EOF
$hostname
EOF"

# Create a new hosts file
sudo bash -c "cat > /mnt/rootfs/etc/hosts << EOF
127.0.0.1       localhost
127.0.1.1       $hostname

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF"

# Create a new sysctl file with `kernel.printk` uncommented
sudo bash -c 'cat > /mnt/rootfs/etc/sysctl.d/99-sysctl.conf << EOF
#
# /etc/sysctl.conf - Configuration file for setting system variables
# See /etc/sysctl.d/ for additional system variables.
# See sysctl.conf (5) for information.
#

#kernel.domainname = example.com

# Uncomment the following to stop low-level messages on console
kernel.printk = 3 4 1 3

###################################################################
# Functions previously found in netbase
#

# Uncomment the next two lines to enable Spoof protection (reverse-path filter)
# Turn on Source Address Verification in all interfaces to
# prevent some spoofing attacks
#net.ipv4.conf.default.rp_filter=1
#net.ipv4.conf.all.rp_filter=1

# Uncomment the next line to enable TCP/IP SYN cookies
# See http://lwn.net/Articles/277146/
# Note: This may impact IPv6 TCP sessions too
#net.ipv4.tcp_syncookies=1

# Uncomment the next line to enable packet forwarding for IPv4
#net.ipv4.ip_forward=1

# Uncomment the next line to enable packet forwarding for IPv6
#  Enabling this option disables Stateless Address Autoconfiguration
#  based on Router Advertisements for this host
#net.ipv6.conf.all.forwarding=1


###################################################################
# Additional settings - these settings can improve the network
# security of the host and prevent against some network attacks
# including spoofing attacks and man in the middle attacks through
# redirection. Some network environments, however, require that these
# settings are disabled so review and enable them as needed.
#
# Do not accept ICMP redirects (prevent MITM attacks)
#net.ipv4.conf.all.accept_redirects = 0
#net.ipv6.conf.all.accept_redirects = 0
# _or_
# Accept ICMP redirects only for gateways listed in our default
# gateway list (enabled by default)
# net.ipv4.conf.all.secure_redirects = 1
#
# Do not send ICMP redirects (we are not a router)
#net.ipv4.conf.all.send_redirects = 0
#
# Do not accept IP source route packets (we are not a router)
#net.ipv4.conf.all.accept_source_route = 0
#net.ipv6.conf.all.accept_source_route = 0
#
# Log Martian Packets
#net.ipv4.conf.all.log_martians = 1
#

###################################################################
# Magic system request Key
# 0=disable, 1=enable all, >1 bitmask of sysrq functions
# See https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html
# for what other values do
#kernel.sysrq=438
EOF'

# Change root password
echo "root:$password" | sudo chroot /mnt/rootfs/ chpasswd

# Unmount the device
sudo umount "${device}2"
