profile_penyu() {
	profile_standard
	kernel_flavors=""
	kernel_cmdline="unionfs_size=512M console=tty0 console=ttyS0,115200"
	syslinux_serial="0 115200"
	kernel_addons=""
	apks="$apks bkeymaps alpine-base alpine-mirrors network-extras openssl openssh chrony tzdata docker python"
	local _k _a
	for _k in $kernel_flavors; do
		apks="$apks linux-$_k"
		for _a in ; do
			apks="$apks $_a-$_k"
		done
	done
	apks="$apks linux-firmware"
}
