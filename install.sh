#!/bin/sh

bootpartitionsize="500M"
disk="/dev/`lsblk | grep disk | sed -n 1p | awk '{print $1}'`"
swapsize="`grep MemTotal /proc/meminfo | awk '{print $2}'`K";
mountpoint="/mnt"
xbpsrepository="http://repo3.voidlinux.eu/current"
timezone="America/Chicago"
keymap="us"
libclocale="en_us.UTF-8"
[ -f ./config.cfg ] && echo "Reading configuration file" && source ./config.cfg

# Paritition Disk
fdisk $disk <<EOF
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
xbps-install -Sy -R $xbpsrepository -r /mnt base-system grub ed

# Write the *real* install script
xbps-install -Sy bind-utils ed
ip_address=`ip a | grep 'inet' | grep -v ' lo' | awk '{print $2}' | sed 's/\/.*$//'`
hostname=`dig +short -x $ip_address | sed 's/\..*$//'`
[ -z "$hostname" ] && hostname="void-computer"
ed -s ./chroot_install.sh <<EOF
,s/%HOSTNAME%/$hostname/g
,s/%DISK%/$disk/g
,s/%TIMEZONE%/$timezone/g
,s/%KEYMAP%/$keymap/g
,s/%LIBCLOCALE%/$libclocale/g
w
EOF

# Copy file and make sure it is executable
cp ./chroot_install.sh $mountpoint
chmod +x "${mountpoint}/chroot_install.sh"

# Mount dev, bind, proc, etc into chroot
mount -t proc proc "${mountpoint}/proc"
mount -t sysfs sys "${mountpoint}/sys"
mount -o bind /dev "${mountpoint}/dev"
mount -t devpts pts "${mountpoint}/dev/pts"

cd $mountpoint
# Run the install tasks
chroot $mountpoint "./chroot_install.sh"
