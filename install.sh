#!/bin/sh

bootpartitionsize="500M"
disk="/dev/`lsblk | sed -n 2p | awk '{print $1}'`"
swapsize="`grep MemTotal /proc/meminfo | awk '{print $2}'`K";
mountpoint="/mnt"
xbpsrepository="http://repo3.voidlinux.eu/current"
[ -f ./config.cfg ] || (echo "Config File Not Found" && exit 1)
echo "Reading configuration file"
source ./config.cfg

# Paritition Disk
fdisk -u -p $disk << EOF
o
n
p
1

+$bootpartitionsize
n
p
2

+$swapsize
n
p
3


a
1
p
w
q
EOF

# Make Filesystems
mkfs.ext4 "${disk}1"
mkfs.ext4 "${disk}3"
mkswap "${disk}2"

# Mount our chroot
mount "${disk}3" $mountpoint
mkdir "${mountpoint}/boot"
mount "${disk}1" "${mountpoint}/boot"

# Get an IP address
dhcpcd

# Install a base system
xbps-install -S -R $xbpsrepository -r /mnt base-system grub

# Write the *real* install script


# Mount dev, bind, proc, etc into chroot
mount -t proc proc "${mountpoint}/proc"
mount -t sysfs sys "${mountpoint}/sys"
mount -o bind /dev "${mountpoint}/dev"
mount -t devpts pts "${mountpoint}/pts"

cd $mountpoint
# Run the install tasks
chroot $mountpoint "./chrootInstall.sh"
