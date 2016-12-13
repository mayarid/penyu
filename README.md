# Penyu OS Builder

## Build ISO
~~~bash
$ git clone https://github.com/aksaramaya/penyu.git
$ cd penyu
$ docker-compose run build bash
$ cd /opt
$ abuild-keygen -i
$ cat /root/.abuild/abuild.conf >>/etc/abuild.conf
$ apk update
$ make PROFILE=penyu iso
$ make PROFILE=penyu sha1
~~~
