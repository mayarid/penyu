#!/usr/bin/make -f

PROFILE		?= penyu
-include $(PROFILE).conf.mk

BUILD_DATE	:= $(shell date +%y%m%d)
PENYU_RELEASE	?= $(BUILD_DATE)
PENYU_NAME	?= penyu
PENYU_ARCH	?= $(shell abuild -A)
APKS		?= $(shell sed 's/\#.*//; s/\*/\\*/g' $(PROFILE).packages | paste -sd " " - )
BUILD_DIR	?= $(shell pwd)

all: bootstrap build

bootstrap:
	@echo "==> create signing keys"
	@sudo chown am /tmp
	@sudo chown am * -R
	abuild-keygen -i -n -a
	#cat /root/.abuild/abuild.conf >>/etc/abuild.conf
	ls /etc/apk/keys/

	@echo "==> clone aports"
	@if [ ! -d "aports" ]; then git clone git://git.alpinelinux.org/aports --branch=3.6-stable aports;fi

	@echo "==> update packages"
	sudo apk update

build:
	@echo "==> start : generate profile file"
	mkdir iso
	sh ./build.sh "$(PROFILE)" "$(KERNEL_FLAVOR)" "$(MODLOOP_EXTRA)" "$(APKS)" "$(BUILD_DIR)" "$(PENYU_ARCH)"

clean:
	@echo "==> start : clean data"
	@sudo rm -rf iso mkimage.*