if [ "$(tty)" = "/dev/tty1" ] ; then
    grep -q auto /proc/cmdline
    rc=$?
    if [ $rc -eq 0 ] ; then
	cd /opt/void-autoinstall/
	bash install.sh
    fi
fi
