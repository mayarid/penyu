FROM alpine:3.6
MAINTAINER ibnu yahya <anak10thn@gmail.com>

ENV LANG=C.UTF-8 LC_ALL=C

RUN apk --update add bash sudo alpine-sdk xorriso syslinux;
