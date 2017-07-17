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
iface wlan0 inet dhcp
EOF

mkdir -p "$tmp"/etc/apk
makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
alpine-base
docker
dnsmasq
hostapd
network-extras
git
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
iface wlan0 inet dhcp

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

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > $HOSTNAME.apkovl.tar.gz