FROM alpine:3.6
MAINTAINER ibnu yahya <anak10thn@gmail.com>

ENV LANG=C.UTF-8 LC_ALL=C

RUN apk --update add bash sudo build-base apk-tools alpine-conf busybox fakeroot syslinux xorriso shadow abuild git

RUN adduser -s /bin/sh -S am -G abuild

USER am