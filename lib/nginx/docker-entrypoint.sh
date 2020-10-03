#!/bin/bash

set -ex
log(){
  echo -e "[$(date +'%D %H:%M:%S %Z')] - $*"
}
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
envsubst < /passwd.template > /tmp/passwd
export LD_PRELOAD=/usr/lib64/libnss_wrapper.so
export NSS_WRAPPER_PASSWD=/tmp/passwd
export NSS_WRAPPER_GROUP=/etc/group

id
/usr/bin/rm -f /var/run/nginx.pid
sed -i -e "s/%%SERVERENDPOINT%%:%%SERVERPORT%%/${BACKEND_HOST}:${BACKEND_SERVER_PORT}/g" /etc/nginx/conf.d/sarjitsu_nginx.conf
/usr/sbin/nginx -V
/usr/sbin/nginx -t
/usr/sbin/nginx -g 'daemon off;'
