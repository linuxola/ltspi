# ltspi
![alt_text](https://github.com/linuxola/ltspi/raw/master/images/photo_2016-12-13_23-35-26.png "Raspberry Pis as fat clients in Kampala, Uganda")

How-to setup an Ubuntu 16.04 based LTSP server with Raspberry Pis as fat clients with PXE network boot. The setup is for a server with at least two interfaces. One for serving the clients and one for internet connection.
## Prerequisites
* Running Ubuntu 16.04
* To "next" branch flashed Raspberry Pis for PXE boot. See: https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/net_tutorial.md "CLIENT CONFIGURATION"
* Two network interfaces otherwise the network configuration will fail.

## Installation
1. Become root
 
 ```
 sudo su -
 ```
 
2. Install LTSP server and client management software epoptes
 
 ```
apt --yes --install-recommends install ltsp-server-standalone vim epoptes subversion dnsmasq qemu-user-static binfmt-support
 ```
3. Configure one network interface with the IP 192.168.67.1/24 via desktop or in terminal with
 
 In NetworkManager
 
 ```
 nmcli c modify <CONNECTION of output from nmcli d status> ipv4.method manual ipv4.addresses 192.168.67.1/24 ipv4.never-default yes
 nmcli d reapply <name of device>
 ```
 
 Directly in /etc/network/interfaces
 
 ```
 cat << EOF >> /etc/network/interfaces
 auto <interface name from e.g. ip a>
 iface <interface name from e.g. ip a> inet static
 address 192.168.67.1/24
 EOF
 ```
 
 
4. Configure the dnsmasq service to provide DHCP for range 192.168.67.20-250 and tftp service
 
 ```
 cat << EOF > /etc/dnsmasq.d/ltsp-server-dnsmasq.conf
 dhcp-range=192.168.67.20,192.168.67.250,8h
 dhcp-option=17,/opt/ltsp/armhf
 pxe-service=0,"Raspberry Pi Boot"
 enable-tftp
 tftp-root=/var/lib/tftpboot/
 EOF
 ```
 
5. Restart dnsmasq service
 
 ```
 systemctl restart dnsmasq
 ```
 
6. Configure the building of the client with lubuntu-desktop. lubuntu-desktop can certainly be replaced with another preferred desktop.
 
 ```
 cat << EOF > /etc/ltsp/ltsp-build-client-raspi2.conf
 MOUNT_PACKAGE_DIR="/var/cache/apt/archives"
 KERNEL_ARCH="raspi2"
 FAT_CLIENT=1
 FAT_CLIENT_DESKTOPS="lubuntu-desktop"
 LATE_PACKAGES="dosfstools less nano vim ssh firefox epoptes-client"
 EOF
 ```
7. Build the client
 
 ```
 ltsp-build-client --arch armhf --config /etc/ltsp/ltsp-build-client-raspi2.conf
 ```
 
8. Change directory to /var/lib/tftpboot/
 
 ```
 cd /var/lib/tftpboot/
 ```
 
9. Check out firmware for Raspberry Pi from their Github repository’s next branch
 
 ```
 svn co https://github.com/raspberrypi/firmware/branches/next/boot/ .
 ```
 
12. Create symbolic links from kernel in /var/lib/tftpboot. It is important, that the symlink’s destination is relative to this  folder. Otherwise the tftp server’s chroot cannot follow it!

 ```
 ln -s ltsp/armhf/vmlinuz vmlinuz && ln -s ltsp/armhf/initrd.img initrd.img
 ```
 
13. Create configuration file for Raspberry Pi boot
 
 ```
 cat << EOF > config.txt
 dtparam=i2c_arm=on
 dtparam=spi=on
 disable_overscan=1
 hdmi_force_hotplug=1
 kernel vmlinuz
 initramfs initrd.img
 start_x=1
 EOF
 ```
 
14. Create the kernel command-line file
 
 ```
 cat << EOF > cmdline.txt
 dwc_otg.lpm_enable=0 console=serial0,115200 kgdboc=serial0,115200 console=tty1 init=/sbin/init-ltsp nbdroot=192.168.67.1:/opt/ltsp/armhf root=/dev/nbd0 elevator=deadline rootwait
 EOF
 ```
15. Enjoy!

## Additional configurations
### Enable internet access for LTSP clients (untested)
```
sudo su -
apt install iptables-persistent
iptables --table nat --append POSTROUTING --jump MASQUERADE --source 192.168.67.0/24
sudo netfilter-persistent save
echo “net.ipv4.ip_forward=1” >> /etc/sysctl.conf
```
