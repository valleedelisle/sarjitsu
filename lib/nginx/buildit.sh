#!/bin/bash -xe
root_dir=$(git rev-parse --show-toplevel)
DIR=""
CONTAINER_NAME=""
ctr1=""
mnt=""
FEDORA_RELEASE=25
source ${root_dir}/lib/buildah.sh
setup_buildah $0
clean_and_setup
buildah run $ctr1 -- dnf -y install nginx
buildah run $ctr1 -- dnf clean all
cp conf/sarjitsu_nginx.conf.example ${mnt}/etc/nginx/conf.d/sarjitsu_nginx.conf
cp conf/nginx.conf.example ${mnt}/etc/nginx/nginx.conf
mkdir -p ${mnt}/var/cache/nginx
buildah run $ctr1 -- sh -c 'chgrp -R 0 /var/cache/nginx /etc/nginx /var/log/nginx/ /var/lib/nginx/ \
                            && chmod -R g+rwX /var/cache/nginx /etc/nginx /var/log/nginx/ /var/lib/nginx/ \
                            && chown -R nginx:root /var/cache/nginx /etc/nginx/ /var/log/nginx/ /var/lib/nginx/'

buildah unmount $ctr1
buildah config --user nginx $ctr1
buildah config \
   --env BACKEND_HOST=${BACKEND_HOST} \
   --env BACKEND_SERVER_PORT=${BACKEND_SERVER_PORT} \
   --env PROXY_PORT=${PROXY_PORT} \
   $ctr1

buildah config --volume='/var/cache/nginx' $ctr1
buildah commit $ctr1 sarjitsu:${CONTAINER_NAME}
