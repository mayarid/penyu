build_penyuxen() {
	apk fetch --root "$APKROOT" --stdout xen-hypervisor | tar -C "$DESTDIR" -xz boot
}

section_penyuxen() {
	[ -n "${xen_params+set}" ] || return 0
	build_section penyuxen $ARCH $(apk fetch --root "$APKROOT" --simulate xen-hypervisor | checksum)
}