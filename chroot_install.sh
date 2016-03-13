#!/bin/sh

# Fix permissions
chown root:root /
chmod 755 /

# Set the hostname
echo "%HOSTNAME%" > /etc/hostname

# Fix the rc.conf file
ed -s /etc/rc.conf <<EOF
,s_void-live_%HOSTNAME%_
,s,Europe/Madrid,%TIMEZONE%,
,s/"es"/"%KEYMAP%"
/HOSTNAME/s/#//
/HARDWARECLOCK/s/#//
/TIMEZONE/s/#//
/KEYMAP/s/#//
w
EOF

# Grab UUIDS
uuid1=`blkid | grep '%DISK%1:' | awk -F '"' '{print $2}'`
uuid2=`blkid | grep '%DISK%2:' | awk -F '"' '{print $2}'`
uuid3=`blkid | grep '%DISK%3:' | awk -F '"' '{print $2}'`

# Fix the fstab file
ed -s /etc/fstab <<EOF
/tempfs/d
a
UUID=$uuid3 / ext4 defaults,errors=remount-ro 0 1
UUID=$uuid1 /boot ext4 defaults 0 2
UUID=$uuid2 swap swap defaults 0 0
.
w
EOF

# Set the libc-locale
ed -s /etc/default/libc-locales <<EOF
/%LIBCLOCALE%/s/#//
w
EOF

xbps-reconfigure -f glibc-locales

# Set hostonly
echo "hostonly=yes" > /etc/dracut.conf.d/hostonly.conf

# Choose the newest kernel
kernel_version=`ls /lib/modules | cut -f1,2 -d'.' | uniq | sort -Vr | sed -n 1p`

# Install grub
grub-install
xbps-reconfigure -f "linux${kernel_version}"
