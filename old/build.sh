#!/bin/bash
cd /opt
abuild-keygen -i -n -a
cat /root/.abuild/abuild.conf >>/etc/abuild.conf
apk update
make PROFILE=penyu iso
make PROFILE=penyu sha1
