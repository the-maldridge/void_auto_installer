#!/bin/bash

# These functions pulled from void's excellent mklive.sh


info_msg() {
    printf "\033[1m$@\n\033[m"
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

welcome() {
    clear
    printf "============================================================="
    printf "================ Void Linux Auto-Installer =================="
    printf "============================================================="
}

get_address() {
    # Get an IP address
    dhcpcd -w
    sleep 15
}

partition_disk() {
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
}

format_disk() {
    # Make Filesystems
    mkfs.ext4 -F "${disk}1"
    mkfs.ext4 -F "${disk}3"
    mkswap -f "${disk}2"
}

mount_target() {
    # Mount targetfs
    mount "${disk}3" $mountpoint
    mkdir "${mountpoint}/boot"
    mount "${disk}1" "${mountpoint}/boot"
}

install_base_system() {
    # Install a base system
    xbps-install -Sy -R $xbpsrepository -r /mnt base-system grub ed $pkgs
}

template_chroot_script() {
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
}

install_chroot_script() {
    # Copy file and make sure it is executable
    cp ./chroot_install.sh $mountpoint
    chmod +x "${mountpoint}/chroot_install.sh"
}

prepare_chroot() {
    # Mount dev, bind, proc, etc into chroot
    mount -t proc proc "${mountpoint}/proc"
    mount -t sysfs sys "${mountpoint}/sys"
    mount -o bind /dev "${mountpoint}/dev"
    mount -t devpts pts "${mountpoint}/dev/pts"
}

run_chroot_script() {
    # Run the install tasks
    cd $mountpoint
    chroot $mountpoint "./chroot_install.sh"
}


configure_autoinstall() {
    # this has to happen after the network since we might need curl

    # -------------------------- Setup defaults ---------------------------
    bootpartitionsize="500M"
    disk=`lsblk -ipo NAME,TYPE,MOUNTPOINT | awk '{if ($2=="disk") {disks[$1]=0; last=$1} if ($3=="/") {disks[last]++}} END {for (a in disks) {if(disks[a] == 0){print a; break}}}'`
    swapsize="`grep MemTotal /proc/meminfo | awk '{print $2}'`K";
    mountpoint="/mnt"
    xbpsrepository="http://lug.utdallas.edu/mirror/void/current"
    timezone="America/Chicago"
    keymap="us"
    libclocale="en_US.UTF-8"
    username="voidlinux"

    # --------------- Pull config URL out of kernel cmdline -------------------------
    procurl=`awk '{for(i = 1; i <= NF; i++) { split($i,a,"="); if(a[1]=="autourl"){print a[2]} }}' /proc/cmdline`
    if [ -z "$procurl" ]
    then
	info_msg "No config url found in /proc/cmdline."
    else
	xbps-install -Sy curl
	curl -o config.cfg $procurl
    fi

    # ---------------- Parse command line args ----------------------------
    while getopts "u:" opt; do
	case $opt in
	    u)
		xbps-install -Sy curl
		curl -o config.cfg $OPTARG
		;;
	    \?)
		die "Invalid option: -$OPTARG" >&2
		exit 1
		;;
	esac

    done

    # Read in the resulting config file which we got via some method
    [ -f ./config.cfg ] && info_msg "Reading configuration file" && source ./config.cfg

    # Bail out if we didn't get a usable disk
    [ -z "$disk" ] && die "No valid disk!"
}

# ------------------- Install "main()" ----------------------------

CURRENT_STEP=0
STEP_COUNT=9


welcome

print_step "Bring up the network"
get_address

print_step "Configure installer"
configure_autoinstall

print_step "Configuring disk using scheme 'Atomic'"
partition_disk
format_disk

print_step "Mounting the target filesystems"
mount_target

print_step "Installing the base system"
install_base_system

print_step "Configuring chroot installer"
template_chroot_script

print_step "Installing chroot installer"
install_chroot_script

print_step "Prepare the chroot"
prepare_chroot

print_step "Executing chroot installer"
run_chroot_script

info_msg "Installation Complete!"
