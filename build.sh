#!/bin/bash
cd /opt
abuild-keygen -i -n
apk update
make PROFILE=penyu iso
make PROFILE=penyu sha1
