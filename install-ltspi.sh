#!/bin/sh
##############################################################################
# LTSPi installation script
#
# This script will install a Linux Terminal Server Project (LTSP) server for
# Raspberry Pi 3 that are capable booting via PXE on Ubuntu 16.04.
# 
# Copyright (C) 2016 Simon Nussbaum <simon.nussbaum@linuxola.org
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, 
# USA.
##############################################################################

exit_on_error () 
{
    printf "[ERROR] %s\n" "$1"
    exit 1
}

printf "\n#############################\n# LTSPi installation script #\n#############################\n\nThis script will install an LTSP server for Raspberry Pi 3 that are capable of booting via PXE.\nFollow this guide to enable PXE-boot on Raspberry Pi: https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/net_tutorial.md\n\n*** This script only has been tested with Ubuntu 16.04 and Raspberry Pi 3 Model B! ***\n\n"

if [ -d /opt/ltsp/armhf ]; then
    exit_on_error "An ltsp client build exists. The setup cannot continue. Please delete the existing build at /opt/ltsp/armhf (sudo rm -rf /opt/ltsp/armhf)."
fi

answer=""
while [ ! "$answer" = "yes" ]; do
    printf "Do you want to continue with the installation? (yes/no) "
    read answer
    if [ "$answer" = "no" ]; then
        exit 1
	fi
done

printf "\n\n*** Network configuration ***"
success=1
iface=""
if [ -f `which nmcli` ]; then
    while [ $success -ne 0 ]; do
        nmcli c show
	    printf "Please enter the name of the interface you would like to use: "
	    read iface

	    nmcli c m "$iface" ipv4.method manual ipv4.address 192.168.67.1/24 ipv4.never-default yes

	    success=$?
	done

	nmcli d reapply "$iface"
else

    while [ $success -ne 0 ]; do
        ip -o link | awk '{print $2,$9}'

        printf "Make sure that there are no configurations in your network configuration file /etc/network/interfaces!\n\nPlease enter the name of the interface you would like to use: "
        read iface

        ip address change 192.168.67.1/24 dev "$iface"
	    if [ $? -eq 0 ]; then
	        cat << EOF >> /etc/network/interfaces
auto $iface
iface $iface inet static
address 192.168.67.1/24
EOF
            success=0
        fi
    done
fi


printf "\n\n*** Starting installation ... ***\nThis is going to take a while depending on your internet connection speed and this server's performance. Hit enter and grab a cup of coffee."
read val

printf "*** Installing needed packages ***\n\n"
apt --yes --install-recommends install ltsp-server-standalone vim epoptes subversion dnsmasq qemu-user-static binfmt-support || exit_on_error "Failed to install packages"


printf "*** Configuring dnsmasq service ***\n\n"
cat << EOF > /etc/dnsmasq.d/ltsp-server-dnsmasq.conf
dhcp-range=192.168.67.20,192.168.67.250,8h
dhcp-option=17,/opt/ltsp/armhf
pxe-service=0,"Raspberry Pi Boot"
enable-tftp
tftp-root=/var/lib/tftpboot/
EOF

systemctl restart dnsmasq


printf "*** Building configuration for ltsp client build ***\n\n"
cat << EOF > /etc/ltsp/ltsp-build-client-raspi2.conf
MOUNT_PACKAGE_DIR="/var/cache/apt/archives"
KERNEL_ARCH="raspi2"
FAT_CLIENT=1
FAT_CLIENT_DESKTOPS="lubuntu-desktop"
LATE_PACKAGES="dosfstools less nano vim ssh firefox epoptes-client"
EOF


printf "*** Building the client ***"
ltsp-build-client --arch armhf --config /etc/ltsp/ltsp-build-client-raspi2.conf


printf "*** Configuring the ltsp server and PXE boot for the Raspberry Pis ***\n\n"
cd /var/lib/tftpboot/
svn co https://github.com/raspberrypi/firmware/branches/next/boot/ .

if [ -f vmlinuz || -f initrd.img ]; then
    rm vmlinuz initrd.img
fi

ln -s ltsp/armhf/vmlinuz vmlinuz && ln -s ltsp/armhf/initrd.img initrd.img

cat << EOF > config.txt
dtparam=i2c_arm=on
dtparam=spi=on
disable_overscan=1
hdmi_force_hotplug=1
kernel vmlinuz
initramfs initrd.img
start_x=1
EOF

cat << EOF > cmdline.txt
dwc_otg.lpm_enable=0 console=serial0,115200 kgdboc=serial0,115200 console=tty1 init=/sbin/init-ltsp nbdroot=192.168.67.1:/opt/ltsp/armhf root=/dev/nbd0 elevator=deadline rootwait
EOF

ltsp-config lts.conf
printf "\n\n*** INSTALLATION COMPLETED SUCCESSFULLY ***\n\n"
