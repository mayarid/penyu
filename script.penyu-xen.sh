build_penyu-xen() {
	apk fetch --root "$APKROOT" --stdout xen-hypervisor | tar -C "$DESTDIR" -xz boot
}

section_penyu-xen() {
	[ -n "${xen_params+set}" ] || return 0
	build_section xen $ARCH $(apk fetch --root "$APKROOT" --simulate xen-hypervisor | checksum)
}