#!/bin/sh

# These functions pulled from void's excellent mklive.sh


info_msg() {
    printf "\033[1min-target: $@\n\033[m"
}
die() {
    info_msg "ERROR: $@"
    exit 1
}
print_step() {
    CURRENT_STEP=$((CURRENT_STEP+1))
    info_msg "[${CURRENT_STEP}/${STEP_COUNT}] $@"
}

# ----------------------- Install Functions ------------------------

correct_permission() {
    # Fix permissions
    chown root:root /
    chmod 755 /
}

add_user() {
    USERPASS=%PASSWORD%
    useradd -m -s /bin/bash -U -G wheel,users,audio,video,cdrom,input %USERNAME%
    if [ -z "${USERPASS}" ] ; then
	passwd %USERNAME%
    else
	echo "%USERNAME%:${USERPASS}" | chpasswd -c SHA512
    fi
}

grant_sudo() {
    # Give wheel sudo
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
}

set_hostname() {
    # Set the hostname
    echo "%HOSTNAME%" > /etc/hostname
}

configure_rc_conf() {
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
}

configure_fstab() {
    # Grab UUIDS
    uuid1=`blkid | grep '%DISK%1:' | awk -F '"' '{print $2}'`
    uuid2=`blkid | grep '%DISK%2:' | awk -F '"' '{print $2}'`
    uuid3=`blkid | grep '%DISK%3:' | awk -F '"' '{print $2}'`

    # Fix the fstab file
    ed -s /etc/fstab <<EOF
/tmpfs/d
a
UUID=$uuid3 / ext4 defaults,errors=remount-ro 0 1
UUID=$uuid1 /boot ext4 defaults 0 2
UUID=$uuid2 swap swap defaults 0 0
.
w
EOF
}

configure_locale() {
    # Set the libc-locale
    ed -s /etc/default/libc-locales <<EOF
/%LIBCLOCALE%/s/#//
w
EOF

    xbps-reconfigure -f glibc-locales
}

configure_grub() {
    # Set hostonly
    echo "hostonly=yes" > /etc/dracut.conf.d/hostonly.conf

    # Choose the newest kernel
    kernel_version=`ls /lib/modules | cut -f1,2 -d'.' | uniq | sort -Vr | sed -n 1p`

    # Install grub
    grub-install %DISK%
    xbps-reconfigure -f "linux${kernel_version}"
    passwd -l root
}

# -------------- chroot "main()" ---------------------------
CURRENT_STEP=0
STEP_COUNT=8

print_step "Correcting permissions on /"
correct_permission

print_step "Adding initial user %USERNAME%"
add_user

print_step "Granting sudo to initial user: %USERNAME%"
grant_sudo

print_step "Setting hostname to %HOSTNAME%"
set_hostname

print_step "Configuring /etc/rc.conf"
configure_rc_conf

print_step "Configuring mounts in /etc/fstab"
configure_fstab

print_step "Configuring glib-locale"
configure_locale

print_step "Configuring and installing grub"
configure_grub
