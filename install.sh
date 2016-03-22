#!/bin/bash

bootpartitionsize="500M"
disk=`lsblk -ipo NAME,TYPE,MOUNTPOINT | awk '{if ($2=="disk") {disks[$1]=0; last=$1} if ($3=="/") {disks[last]++}} END {for (a in disks) {if(disks[a] == 0){print a; break}}}'`
swapsize="`grep MemTotal /proc/meminfo | awk '{print $2}'`K";
mountpoint="/mnt"
xbpsrepository="http://lug.utdallas.edu/mirror/void/current"
timezone="America/Chicago"
keymap="us"
libclocale="en_US.UTF-8"
username="cv"

procurl=`awk '{for(i = 1; i <= NF; i++) { split($i,a,"="); if(a[1]=="autourl"){print a[2]} }}' /proc/cmdline`

if [ -z "$procurl" ]
then
        echo "No config url found in /proc/cmdline."
else
        xbps-install -Sy curl
        curl -o config.cfg $procurl
fi

while getopts "u:" opt; do
        case $opt in
                u)
                        xbps-install -Sy curl
                        curl -o config.cfg $OPTARG
                        ;;
                \?)
                        echo "Invalid option: -$OPTARG" >&2
                        exit 1
                        ;;
        esac

done

[ -f ./config.cfg ] && echo "Reading configuration file" && source ./config.cfg
[ -z "$disk" ] && echo "No disk found." && exit 1
# Get an IP address
dhcpcd

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
mkfs.ext4 -F "${disk}1"
mkfs.ext4 -F "${disk}3"
mkswap -f "${disk}2"

# Mount our chroot
mount "${disk}3" $mountpoint
mkdir "${mountpoint}/boot"
mount "${disk}1" "${mountpoint}/boot"


# Install a base system
xbps-install -Sy -R $xbpsrepository -r /mnt base-system grub ed $pkgs

# Write the *real* install script
xbps-install -Sy bind-utils ed
ip_address=`ip a | grep 'inet' | grep -v ' lo' | awk '{print $2}' | sed 's/\/.*$//'`
hostname=`dig +short -x $ip_address | sed 's/\..*$//'`
[ -z "$hostname" ] && hostname="void-computer"
ed -s ./chroot_install.sh <<EOF
,s_%HOSTNAME%_${hostname}_g
,s,%DISK%,$disk,g
,s,%TIMEZONE%,$timezone,g
,s/%KEYMAP%/$keymap/g
,s/%LIBCLOCALE%/$libclocale/g
,s/%USERNAME%/$username/g
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
