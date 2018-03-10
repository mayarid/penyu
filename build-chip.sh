#!/bin/bash

set -eo pipefail

readonly PENYU_CHROOT_INSTALL_VERSION="0.6.0"
readonly PENYU_VERSION="latest-stable"
readonly LATEST_BUILDROOT_URL="http://opensource.nextthing.co/chip/buildroot/stable/latest"

readonly GITHUB_REPO="orcinustools/penyu"
readonly GITHUB_LOGIN_USERNAME="anak10thn"
# secure readonly GITHUB_ACCESS_TOKEN

die () {
	printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2  # bold red
	exit 1
}

einfo () {
	printf '\n\033[1;36m> %s\033[0m\n' "$@" >&2  # bold cyan
}

ewarn () {
	printf '\033[1;33m> %s\033[0m\n' "$@" >&2  # bold yellow
}

install_apt_dependencies () {
cp /etc/apt/sources.list /etc/apt/sources.list.ori
cat << EOF > /etc/apt/sources.list
deb http://kebo.pens.ac.id/ubuntu/ zesty main restricted
deb http://kebo.pens.ac.id/ubuntu/ zesty-updates main restricted
deb http://kebo.pens.ac.id/ubuntu/ zesty universe
deb http://kebo.pens.ac.id/ubuntu/ zesty-updates universe
deb http://kebo.pens.ac.id/ubuntu/ zesty multiverse
deb http://kebo.pens.ac.id/ubuntu/ zesty-updates multiverse
deb http://kebo.pens.ac.id/ubuntu/ zesty-backports main restricted universe multiverse
deb http://kebo.pens.ac.id/ubuntu/ zesty-security main restricted
deb http://kebo.pens.ac.id/ubuntu/ zesty-security universe
deb http://kebo.pens.ac.id/ubuntu/ zesty-security multiverse
EOF

apt-get update
apt-get install -y git liblzo2-dev python-lzo mtd-utils python-setuptools wget
}

install_ubi_reader () {
  local temp_dir
  temp_dir=$(mktemp -d -p /tmp ubi_reader.XXXXXX)
  git clone https://github.com/jrspruitt/ubi_reader "${temp_dir}"
  pushd "${temp_dir}"
  python setup.py install
  popd
  rm --recursive "${temp_dir}"
}

install_penyu_chroot_install () {
  local version="${1}"

  wget --quiet --output-document /usr/local/bin/penyu-chroot-install "https://raw.githubusercontent.com/alpinelinux/alpine-chroot-install/v${version}/alpine-chroot-install"
  chmod +x /usr/local/bin/penyu-chroot-install
}

get_latest_buildroot () {
  local latest_buildroot_url="${1}"
  local buildroot_dir="${2}"

  local _latest_buildroot # _ because else conflict with latest_buildroot in main scope
  _latest_buildroot=$(wget --quiet -O- "${latest_buildroot_url}")
  eval "${3}=\"${_latest_buildroot}\""
  local buildroot_rootfs_url
  buildroot_rootfs_url="${_latest_buildroot}/images/rootfs.ubi"

  local temp_dir
  temp_dir=$(mktemp -d -p /tmp buildroot.XXXXXX)

  # download buildroot
  wget --quiet --output-document "${temp_dir}/rootfs.ubi" "${buildroot_rootfs_url}"

  # extract ubi
  pushd "${temp_dir}"
  mkdir extracted
  pushd extracted
  ubireader_extract_files "../rootfs.ubi"
  pushd ubifs-root
  pushd "$(find . -maxdepth 1 ! -path .|head -n 1)"
  pushd rootfs
  cp --archive ./. "${buildroot_dir}"
  popd
  popd
  popd
  popd
  popd
  rm --recursive "${temp_dir}"
}

prepare_penyu () {
  local penyu_version="${1}"
  local penyu_dir="${2}"

  CHROOT_KEEP_VARS="" ALPINE_PACKAGES="wpa_supplicant wireless-tools bkeymaps tzdata nano" penyu-chroot-install -d "${penyu_dir}" -a armhf -b "${penyu_version}"

  "${penyu_dir}/enter-chroot" -u root <<-EOF
    set -e
    # Needed services
    rc-update add devfs sysinit
    rc-update add dmesg sysinit
    rc-update add mdev sysinit

    rc-update add modules boot
    rc-update add sysctl boot
    rc-update add hostname boot
    rc-update add bootmisc boot
    rc-update add syslog boot
    rc-update add wpa_supplicant boot # needed, otherwise does not connect after reboot

    rc-update add mount-ro shutdown
    rc-update add killprocs shutdown
    rc-update add savecache shutdown

    # Allow root login with no password.
    passwd root -d

    # Allow root login from serial.
    echo ttyS0 >> /etc/securetty
    echo ttyGS0 >> /etc/securetty

    # Make sure the USB virtual serial device is available.
    echo g_serial >> /etc/modules

    # Make sure wireless networking is available.
    echo 8723bs >> /etc/modules

    # These enable the USB virtual serial device, and the standard serial
    # pins to both be used as TTYs
    echo ttyS0::respawn:/sbin/getty -L ttyS0 115200 vt102 >> /etc/inittab
    echo ttyGS0::respawn:/sbin/getty -L ttyGS0 115200 vt102 >> /etc/inittab
EOF

  umount -l "${penyu_dir}/proc"
  umount -l "${penyu_dir}/sys"
  umount -l "${penyu_dir}/dev"
  umount -l "${penyu_dir}$(pwd)"

  rm "${penyu_dir}/usr/bin/qemu-arm-static"
  rm "${penyu_dir}/etc/resolv.conf"
  rm "${penyu_dir}/enter-chroot"
}

prepare_rootfs () {
  local buildroot_dir="${1}"
  local penyu_dir="${2}"
  local ubi_dest="${3}"

  local temp_dir
  temp_dir=$(mktemp -d -p /tmp ubi.XXXXXX)

  cp --archive "${buildroot_dir}/boot/." "${penyu_dir}/boot"
  cp --archive "${buildroot_dir}/lib/modules/." "${penyu_dir}/lib/modules"

  pushd "${temp_dir}"
  cat <<EOF >ubinize.cfg
  [ubifs]
  mode=ubi
  vol_id=0
  vol_type=dynamic
  vol_name=rootfs
  vol_alignment=1
  vol_flags=autoresize
  image=rootfs.ubifs
EOF
  mkfs.ubifs -d "${penyu_dir}" -o rootfs.ubifs -e 0x1f8000 -c 2000 -m 0x4000 -x lzo
  ubinize -o "${ubi_dest}" -m 0x4000 -p 0x200000 -s 16384 ubinize.cfg
  popd
  rm --recursive "${temp_dir}"
}

make_penyu_release () {
  local chip_build_dir="${1}"
  local latest_buildroot="${2}"
  local tar_dest="${3}"

  wget --quiet --output-document "${chip_build_dir}/penyu/images/sun5i-r8-chip.dtb" "${latest_buildroot}/images/sun5i-r8-chip.dtb"
  wget --quiet --output-document "${chip_build_dir}/penyu/images/sunxi-spl.bin" "${latest_buildroot}/images/sunxi-spl.bin"
  wget --quiet --output-document "${chip_build_dir}/penyu/images/sunxi-spl-with-ecc.bin" "${latest_buildroot}/images/sunxi-spl-with-ecc.bin"
  wget --quiet --output-document "${chip_build_dir}/penyu/images/uboot-env.bin" "${latest_buildroot}/images/uboot-env.bin"
  wget --quiet --output-document "${chip_build_dir}/penyu/images/zImage" "${latest_buildroot}/images/zImage"
  wget --quiet --output-document "${chip_build_dir}/penyu/images/u-boot-dtb.bin" "${latest_buildroot}/images/u-boot-dtb.bin"

  pushd "${chip_build_dir}"
  tar -zcv -C "${chip_build_dir}" -f "${tar_dest}" penyu
  popd
}

gather_rootfs_versions () {
  local buildroot_dir="${1}"
  local penyu_dir="${2}"

  # shellcheck source=/dev/null
  source "${buildroot_dir}/etc/os-release"
  eval "${3}=\"${VERSION_ID}\""

  # shellcheck source=/dev/null
  source "${penyu_dir}/etc/os-release"
  eval "${4}=\"${VERSION_ID}\""
  eval "${5}=\"${PRETTY_NAME}\""
}

release_github () {
  local repo="${1}"
  local username="${2}"
  local access_token="${3}"
  local tag_name="${4}"
  local release_name="${5}"
  local release_body="${6}"
  local tar_location="${7}"

  local release_json
  release_json=$(printf '{"tag_name": "%s","target_commitish": "master","name": "%s","body": "%s","draft": false,"prerelease": false}' "${tag_name}" "${release_name}" "${release_body}")
  local github_release_id
  github_release_id=$(curl -u "${username}:${access_token}" --data "${release_json}" -v --silent "https://api.github.com/repos/${repo}/releases" 2>&1 | sed -ne 's/^  "id": \(.*\),$/\1/p')

  curl -u "${username}:${access_token}" -X POST -H "Content-Type: application/gzip" --data-binary "@${tar_location}" "https://uploads.github.com/repos/${repo}/releases/${github_release_id}/assets?name=${tag_name}.tar.gz"
}

main () {
  local working_dir
  working_dir=$(mktemp -d -p /tmp chip-penyu.XXXXXX)
  local buildroot_dir="${working_dir}/buildroot"
  mkdir -p "${buildroot_dir}"
  local penyu_dir="${working_dir}/penyu"
  mkdir -p "${penyu_dir}"
  local chip_build_dir="${working_dir}/chip-build"
  mkdir -p "${chip_build_dir}/penyu/images"

  einfo "Installing dependencies..."
  install_apt_dependencies

  einfo "Installing ubi_reader..."
  install_ubi_reader

  einfo "Installing penyu-chroot-install..."
  install_penyu_chroot_install "${PENYU_CHROOT_INSTALL_VERSION}"

  #####
  # Get the latest base buildroot image
  #####

  einfo "Getting latest buildroot..."
  local latest_buildroot=""
  get_latest_buildroot "${LATEST_BUILDROOT_URL}" "${buildroot_dir}" "latest_buildroot"

  #####
  # Get and set-up Penyu
  #####

  einfo "Getting and setting-up Penyu..."
  prepare_penyu "${PENYU_VERSION}" "${penyu_dir}"

  #####
  # Prepare rootfs
  #####

  einfo "Preparing rootfs..."
  prepare_rootfs "${buildroot_dir}" "${penyu_dir}" "${chip_build_dir}/penyu/images/rootfs.ubi"

  #####
  # Make Penyu release
  #####

  einfo "Making Penyu release..."
  local temp_tar
  temp_tar=$(mktemp -p /tmp tar.XXXXXX)
  make_penyu_release "${chip_build_dir}" "${latest_buildroot}" "${temp_tar}"

  einfo "Gathering rootfs versions..."
  local buildroot_version_id=""
  local penyu_version_id=""
  local penyu_pretty_name=""
  gather_rootfs_versions "${buildroot_dir}" "${penyu_dir}" "buildroot_version_id" "penyu_version_id" "penyu_pretty_name"

  #####
  # Create GitHub release
  #####

  # einfo "Releasing on GitHub..."
  # release_github "${GITHUB_REPO}" "${GITHUB_LOGIN_USERNAME}" "${GITHUB_ACCESS_TOKEN}" \
  #   "penyu-${penyu_version_id}_buildroot-${buildroot_version_id}_$(date +%s)" \
  #   "${penyu_pretty_name} with Buildroot ${buildroot_version_id} built on $(date +%Y-%m-%d)" \
  #   "Daily build." \
  #   "${temp_tar}"

  cp "${temp_tar}" /root/penyu-${penyu_version_id}-chip-armv7.tar.gz

  einfo "Done!"
}

main
# tar zxvf penyu*.tar.gz && sudo BUILDROOT_OUTPUT_DIR=penyu/ ./chip-fel-flash.sh
