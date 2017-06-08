#!/bin/sh
APORTDIR="./aports/scripts/"
PROFILENAME=$1
KERNEL_FLAVOR=$2
MODLOOP_EXTRA=$3
APKS=$4
BUILD_DIR=$5
ARCH=$6

cd $APORTDIR
cat << EOF > mkimg.$PROFILENAME.sh
profile_$PROFILENAME() {
	profile_standard
	kernel_flavors="$KERNEL_FLAVOR"
	kernel_cmdline="unionfs_size=512M console=tty0 console=ttyS0,115200"
	syslinux_serial="0 115200"
	kernel_addons="$MODLOOP_EXTRA"
	apks="\$apks $APKS"
	local _k _a
	for _k in \$kernel_flavors; do
		apks="\$apks linux-\$_k"
		for _a in $kernel_addons; do
			apks="\$apks \$_a-\$_k"
		done
	done
	apks="\$apks linux-firmware"
}
EOF

chmod +x mkimg.$PROFILENAME.sh

sh mkimage.sh --tag latest \
	--outdir $BUILD_DIR/iso \
	--arch $ARCH \
	--repository http://dl-cdn.alpinelinux.org/alpine/latest-stable/main \
	--extra-repository http://dl-cdn.alpinelinux.org/alpine/latest-stable/community \
	--profile $PROFILENAME