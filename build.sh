#!/bin/sh
APORTDIR="./aports/scripts"
PROFILENAME=$1
KERNEL_FLAVOR=$2
MODLOOP_EXTRA=$3
APKS=$4
BUILD_DIR=$5
ARCH=$6
PENYU_OVL=$7
PENYU_TYPE=$8

if [ -f "./script.$PROFILENAME.sh" ]
	then
	cat ./script.$PROFILENAME.sh >> $APORTDIR/mkimg.$PROFILENAME.sh
fi

cp $PWD/$PENYU_OVL $APORTDIR
chmod +x $APORTDIR/$PENYU_OVL
cd $APORTDIR
cat << EOF >> mkimg.$PROFILENAME.sh
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
	if [ -f "$PENYU_OVL" ]
		then
		apkovl="$PENYU_OVL"
	fi

	hostname="penyu"
}
EOF

sed -i -e 's|image_name="alpine-${PROFILE}"|image_name="penyu"|g' mkimage.sh

chmod +x mkimg.$PROFILENAME.sh

sh mkimage.sh --tag $PENYU_TYPE \
	--outdir $BUILD_DIR/iso \
	--arch $ARCH \
	--repository http://dl-cdn.alpinelinux.org/alpine/latest-stable/main \
	--extra-repository http://dl-cdn.alpinelinux.org/alpine/latest-stable/community \
	--profile $PROFILENAME