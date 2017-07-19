#!/bin/sh -e

HOSTNAME="penyu"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname"
	exit 1
fi

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

mkdir -p "$tmp"/etc/network
makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto wlan0
iface wlan0 inet static
        address 192.168.7.48
        netmask 255.255.255.0
        gateway 192.168.7.48
EOF

mkdir -p "$tmp"/etc/apk
makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
alpine-base
docker
dnsmasq
hostapd
network-extras
git
hostapd
udhcpd
iptables
EOF

makefile root:root 0644 "$tmp"/etc/issue <<EOF
Welcome to PenyuOS
Kernel \r on an \m (\l)
EOF

makefile root:root 0644 "$tmp"/etc/motd <<EOF
=> PenyuOS Powered by Aksaramaya <http://aksaramaya.com>
        __                                                              
_____  |  | __  ___________ ____________    _____ _____  ___.__._____   
\__  \ |  |/ / /  ___/\__  \\_  __ \__  \  /     \\__  \<   |  |\__  \  
 / __ \|    <  \___ \  / __ \|  | \// __ \|  Y Y  \/ __ \\___  | / __ \_
(____  /__|_ \/____  >(____  /__|  (____  /__|_|  (____  / ____|(____  /
     \/     \/     \/      \/           \/      \/     \/\/          \/ 
=> Bugs : https://github.com/orcinustools/penyu/issues

=> Install : 'sh /etc/installer-script/penyu-default-install'

EOF

mkdir -p "$tmp"/etc/installer-script
makefile root:root 0755 "$tmp"/etc/installer-script/penyu-wifi <<'WIFI'
#!/bin/sh
rm /etc/wpa_supplicant/wpa_supplicant.conf
killall wpa_supplicant

ifconfig wlan0 up

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto wlan0
iface wlan0 inet dhcp
EOF

echo "===> scanning wifi......."

iwlist wlan0 scan | grep 'ESSID\|Encryption'

echo -n "===> Select ESSID : "
read ESSID
iwconfig wlan0 essid $ESSID

echo "===> wifi password : "
wpa_passphrase $ESSID > /etc/wpa_supplicant/wpa_supplicant.conf

wpa_supplicant -B -Dwext -iwlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

service networking restart

ifconfig wlan0
WIFI

makefile root:root 0755 "$tmp"/etc/udhcpd.conf <<'UDHCP'
start				192.168.7.49
end					192.168.7.254
max_leases	64
interface	wlan0
opt	dns	192.168.7.48 8.8.8.8
opt	subnet	255.255.255.0
opt	router	192.168.7.48
opt	lease	864000
UDHCP

mkdir -p "$tmp"/etc/hostapd
makefile root:root 0755 "$tmp"/etc/hostapd/hostapd.conf <<'HOSTAPD'
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
interface=wlan0
#driver=nl80211
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
ssid=ijakarta.id
hw_mode=g
channel=6
max_num_sta=32
rts_threshold=2347
fragm_threshold=2346
macaddr_acl=0
auth_algs=3
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=1234567890
wpa_key_mgmt=WPA-PSK WPA-PSK-SHA256
wpa_pairwise=TKIP CCMP
HOSTAPD

makefile root:root 0755 "$tmp"/etc/installer-script/penyu-default-install <<'EOF'
#!/bin/sh
cat > /tmp/welcome.txt <<'_EOF_'
=> PenyuOS installer.....
        __                                                              
_____  |  | __  ___________ ____________    _____ _____  ___.__._____   
\__  \ |  |/ / /  ___/\__  \\_  __ \__  \  /     \\__  \<   |  |\__  \  
 / __ \|    <  \___ \  / __ \|  | \// __ \|  Y Y  \/ __ \\___  | / __ \_
(____  /__|_ \/____  >(____  /__|  (____  /__|_|  (____  / ____|(____  /
     \/     \/     \/      \/           \/      \/     \/\/          \/ 
=> Bugs : https://github.com/orcinustools/penyu/issues
_EOF_

cat > /tmp/installer.conf <<'_EOF_'
# Example answer file for setup-penyu script
# If you don't want to use a certain option, then comment it out

# Use US layout with US variant
KEYMAPOPTS="us us"

# Set hostname to penyu-test
HOSTNAMEOPTS="-n penyu"

# Contents of /etc/network/interfaces
INTERFACESOPTS="auto lo
iface lo inet loopback

auto wlan0
iface wlan0 inet static
    address 192.168.7.48
    netmask 255.255.255.0
    gateway 192.168.7.48

auto eth0
iface eth0 inet dhcp
    hostname penyu
"

# Search domain of example.com, Google public nameserver
DNSOPTS=""

# Set timezone to UTC
TIMEZONEOPTS="-z UTC"

# set http/ftp proxy
PROXYOPTS="none"

APKREPOSOPTS="-r"

# Install Openssh
SSHDOPTS="-c openssh"

# Use openntpd
NTPOPTS="-c chrony"

# Use /dev/sda as a data disk
DISKOPTS="-m sys /dev/sda"

_EOF_

cat /tmp/welcome.txt

/sbin/setup-alpine -f /tmp/installer.conf

EOF

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add docker boot
rc_add udhcpd boot
rc_add hostapd boot

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > $HOSTNAME.apkovl.tar.gz